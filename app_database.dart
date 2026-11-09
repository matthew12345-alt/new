import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/task.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get _database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'tasks.db');
    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE tasks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            category TEXT NOT NULL DEFAULT 'General',
            due_at INTEGER NOT NULL,
            status INTEGER NOT NULL DEFAULT 0,
            pre_alert_minutes INTEGER,
            created_at INTEGER NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE notes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            task_id INTEGER NOT NULL,
            content TEXT NOT NULL,
            note_time INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE
          )''');
        await db.execute('CREATE INDEX idx_notes_task ON notes(task_id)');
      },
    );
  }

  // ---- Tasks ----
  Future<List<Task>> getTasks() async {
    final db = await _database;
    final rows = await db.query('tasks', orderBy: 'due_at ASC');
    return rows.map(Task.fromMap).toList();
  }

  Future<int> insertTask(Task t) async =>
      (await _database).insert('tasks', t.toMap());

  Future<void> updateTask(Task t) async => (await _database)
      .update('tasks', t.toMap(), where: 'id = ?', whereArgs: [t.id]);

  Future<void> deleteTask(int id) async =>
      (await _database).delete('tasks', where: 'id = ?', whereArgs: [id]);

  // ---- Notes ----
  Future<List<TaskNote>> getNotes(int taskId) async {
    final rows = await (await _database).query('notes',
        where: 'task_id = ?', whereArgs: [taskId], orderBy: 'note_time DESC');
    return rows.map(TaskNote.fromMap).toList();
  }

  Future<int> insertNote(TaskNote n) async =>
      (await _database).insert('notes', n.toMap());

  Future<void> updateNote(TaskNote n) async => (await _database)
      .update('notes', n.toMap(), where: 'id = ?', whereArgs: [n.id]);

  Future<void> deleteNote(int id) async =>
      (await _database).delete('notes', where: 'id = ?', whereArgs: [id]);
}
