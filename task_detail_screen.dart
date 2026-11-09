import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/settings_provider.dart';
import '../providers/task_provider.dart';
import '../utils.dart';
import 'task_editor.dart';

class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({super.key, required this.taskId});
  final int taskId;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    context.read<TaskProvider>().loadNotes(widget.taskId);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _delete(Task task) async {
    final provider = context.read<TaskProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: const Text('The task and all its notes will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await provider.deleteTask(task);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final defaultPre = context.watch<SettingsProvider>().preAlertMinutes;
    final task = provider.byId(widget.taskId);

    if (task == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Task not found')),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final state = task.stateAt(now, defaultPre);
    final color = stateColor(state, cs);
    final notes = provider.notesFor(task.id!);

    final String countdown = switch (state) {
      DueState.completed => 'Completed',
      DueState.overdue => 'Overdue by ${formatCountdown(now.difference(task.dueAt))}',
      _ => 'Due in ${formatCountdown(task.dueAt.difference(now))}',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showTaskEditor(context, task: task),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(task),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showNoteEditor(context, taskId: task.id!),
        icon: const Icon(Icons.note_add_outlined),
        label: const Text('Add note'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Text(task.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.label_outline, size: 18),
                label: Text(task.category),
              ),
              Chip(
                avatar: const Icon(Icons.notifications_active_outlined, size: 18),
                label: Text(preAlertLabel(task.preAlertMinutes, defaultPre)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: color.withValues(alpha: 0.14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    countdown,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(formatDateTime(task.dueAt)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<TaskStatus>(
              showSelectedIcon: false,
              segments: [
                for (final s in TaskStatus.values)
                  ButtonSegment(
                    value: s,
                    label: Text(s.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
              ],
              selected: {task.status},
              onSelectionChanged: (s) => provider.setStatus(task, s.first),
            ),
          ),
          if (task.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Description', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(task.description),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(Icons.history, color: cs.primary),
              const SizedBox(width: 8),
              Text('Timed notes (${notes.length})',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          if (notes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No notes yet. Add progress updates or meeting logs and '
                'stamp them with the time they happened.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            )
          else
            for (final n in notes) _NoteTile(note: n),
        ],
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.note});
  final TaskNote note;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.sticky_note_2_outlined),
        title: Text(note.content),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(formatDateTime(note.noteTime),
              style: TextStyle(color: cs.primary)),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') {
              showNoteEditor(context, taskId: note.taskId, note: note);
            } else {
              context.read<TaskProvider>().deleteNote(note);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}

Future<void> showNoteEditor(
  BuildContext context, {
  required int taskId,
  TaskNote? note,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _NoteEditor(taskId: taskId, note: note),
  );
}

class _NoteEditor extends StatefulWidget {
  const _NoteEditor({required this.taskId, this.note});
  final int taskId;
  final TaskNote? note;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _text;
  late DateTime _when;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.note?.content);
    _when = widget.note?.noteTime ?? DateTime.now();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() => _when = DateTime(d.year, d.month, d.day, _when.hour, _when.minute));
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (t != null) {
      setState(() => _when = DateTime(_when.year, _when.month, _when.day, t.hour, t.minute));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<TaskProvider>();
    final existing = widget.note;
    final note = existing == null
        ? TaskNote(
            taskId: widget.taskId,
            content: _text.text.trim(),
            noteTime: _when,
            createdAt: DateTime.now(),
          )
        : existing.copyWith(content: _text.text.trim(), noteTime: _when);
    await provider.saveNote(note);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.note != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isEdit ? 'Edit note' : 'New note',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _text,
                autofocus: true,
                minLines: 3,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  alignLabelWithHint: true,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Write something' : null,
              ),
              const SizedBox(height: 16),
              const Text('Timestamp'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        '${_when.year}-${_when.month.toString().padLeft(2, '0')}-${_when.day.toString().padLeft(2, '0')}',
                      ),
                      onPressed: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time),
                      label: Text(formatTime(_when)),
                      onPressed: _pickTime,
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.update),
                  label: const Text('Set to now'),
                  onPressed: () => setState(() => _when = DateTime.now()),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.save),
                  label: Text(isEdit ? 'Save note' : 'Add note'),
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
