import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/settings_provider.dart';
import '../providers/task_provider.dart';
import '../utils.dart';

const kCategories = [
  'General',
  'Work',
  'Personal',
  'Health',
  'Study',
  'Finance',
  'Other',
];

Future<void> showTaskEditor(BuildContext context, {Task? task}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => TaskEditorSheet(task: task),
  );
}

class TaskEditorSheet extends StatefulWidget {
  const TaskEditorSheet({super.key, this.task});
  final Task? task;

  @override
  State<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<TaskEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _desc;
  late String _category;
  late DateTime _due;
  int? _pre; // null = default

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _title = TextEditingController(text: t?.title);
    _desc = TextEditingController(text: t?.description);
    _category = t?.category ?? 'General';
    _pre = t?.preAlertMinutes;
    final n = DateTime.now();
    _due = t?.dueAt ?? DateTime(n.year, n.month, n.day, n.hour + 1);
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() => _due = DateTime(d.year, d.month, d.day, _due.hour, _due.minute));
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_due),
    );
    if (t != null) {
      setState(() => _due = DateTime(_due.year, _due.month, _due.day, t.hour, t.minute));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<TaskProvider>();
    final existing = widget.task;
    final title = _title.text.trim();
    final desc = _desc.text.trim();

    final Task task = existing == null
        ? Task(
            title: title,
            description: desc,
            category: _category,
            dueAt: _due,
            preAlertMinutes: _pre,
            createdAt: DateTime.now(),
          )
        : existing.copyWith(
            title: title,
            description: desc,
            category: _category,
            dueAt: _due,
            preAlertMinutes: _pre,
            clearPreAlert: _pre == null,
          );

    await provider.saveTask(task);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final defaultPre = context.watch<SettingsProvider>().preAlertMinutes;
    final isEdit = widget.task != null;
    final past = _due.isBefore(DateTime.now());

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isEdit ? 'Edit task' : 'New task',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _desc,
                textCapitalization: TextCapitalization.sentences,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 16),
              const Text('Category'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in kCategories)
                    ChoiceChip(
                      label: Text(c),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Due'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        '${_due.year}-${_due.month.toString().padLeft(2, '0')}-${_due.day.toString().padLeft(2, '0')}',
                      ),
                      onPressed: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time),
                      label: Text(formatTime(_due)),
                      onPressed: _pickTime,
                    ),
                  ),
                ],
              ),
              if (past)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'This time has already passed, so no alerts will fire.',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              const SizedBox(height: 16),
              Text('Almost-due alert: ${preAlertLabel(_pre, defaultPre)}'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final opt in <int?>[null, 0, 5, 10, 15, 30, 60])
                    ChoiceChip(
                      label: Text(opt == null
                          ? 'Default'
                          : opt == 0
                              ? 'Off'
                              : '$opt min'),
                      selected: _pre == opt,
                      onSelected: (_) => setState(() => _pre = opt),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.save),
                  label: Text(isEdit ? 'Save changes' : 'Create task'),
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
