import 'package:flutter/foundation.dart';

import '../db/app_database.dart';
import '../models/task.dart';
import '../services/notification_service.dart';
import 'settings_provider.dart';

class TaskProvider extends ChangeNotifier {
  TaskProvider(this._settings);

  final SettingsProvider _settings;
  final AppDatabase _db = AppDatabase.instance;
  final NotificationService _notifications = NotificationService.instance;

  List<Task> _tasks = [];
  final Map<int, List<TaskNote>> _notes = {};
  bool loading = true;

  List<Task> get tasks => List.unmodifiable(_tasks);

  Task? byId(int id) {
    for (final t in _tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  List<TaskNote> notesFor(int taskId) => _notes[taskId] ?? const [];

  Future<void> init() async {
    _tasks = await _db.getTasks();
    loading = false;
    notifyListeners();
    await rescheduleAll();
  }

  Future<void> rescheduleAll() => _notifications.rescheduleAll(
        _tasks,
        _settings.preAlertMinutes,
      );

  // ---- Tasks ----
  Future<void> saveTask(Task task) async {
    Task saved = task;
    if (task.id == null) {
      final id = await _db.insertTask(task);
      saved = task.copyWith(id: id);
      _tasks.add(saved);
    } else {
      await _db.updateTask(task);
      final i = _tasks.indexWhere((t) => t.id == task.id);
      if (i >= 0) _tasks[i] = task;
    }
    _tasks.sort((a, b) => a.dueAt.compareTo(b.dueAt));
    notifyListeners();
    await _notifications.scheduleTask(saved, _settings.preAlertMinutes);
  }

  Future<void> setStatus(Task task, TaskStatus status) =>
      saveTask(task.copyWith(status: status));

  Future<void> deleteTask(Task task) async {
    final id = task.id;
    if (id == null) return;
    await _notifications.cancelTask(id);
    await _db.deleteTask(id);
    _tasks.removeWhere((t) => t.id == id);
    _notes.remove(id);
    notifyListeners();
  }

  // ---- Notes ----
  Future<void> loadNotes(int taskId) async {
    _notes[taskId] = await _db.getNotes(taskId);
    notifyListeners();
  }

  Future<void> saveNote(TaskNote note) async {
    if (note.id == null) {
      await _db.insertNote(note);
    } else {
      await _db.updateNote(note);
    }
    await loadNotes(note.taskId);
  }

  Future<void> deleteNote(TaskNote note) async {
    if (note.id == null) return;
    await _db.deleteNote(note.id!);
    await loadNotes(note.taskId);
  }
}
