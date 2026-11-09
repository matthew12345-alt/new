import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/settings_provider.dart';
import '../providers/task_provider.dart';
import '../services/notification_service.dart';
import '../utils.dart';
import 'task_detail_screen.dart';
import 'task_editor.dart';

enum _Filter {
  today('Today'),
  upcoming('Upcoming'),
  completed('Completed'),
  all('All');

  const _Filter(this.label);
  final String label;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialTaskId});
  final int? initialTaskId;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Timer? _ticker;
  _Filter _filter = _Filter.today;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Refresh "due soon" highlighting while the screen is open.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final id = widget.initialTaskId;
      if (id != null && mounted) {
        Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => TaskDetailScreen(taskId: id)));
      }
      await _ensurePermissions();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user may have just granted exact-alarm access in system settings.
    if (state == AppLifecycleState.resumed) {
      context.read<TaskProvider>().rescheduleAll();
    }
  }

  Future<void> _ensurePermissions() async {
    final notifications = NotificationService.instance;
    final settings = context.read<SettingsProvider>();
    final tasks = context.read<TaskProvider>();
    final messenger = ScaffoldMessenger.of(context);

    if (!await notifications.notificationsEnabled()) {
      if (!mounted) return;
      final ok = await _confirm(
        title: 'Allow notifications?',
        message: 'Daily Tasks needs notification permission to remind you '
            'before a task is due and when it is due.',
        confirm: 'Allow',
      );
      if (ok) {
        final granted = await notifications.requestNotificationPermission();
        if (!granted) {
          messenger.showSnackBar(const SnackBar(
            content: Text('Notifications are off. Enable them in system '
                'Settings > Apps > Daily Tasks to get reminders.'),
            duration: Duration(seconds: 6),
          ));
        }
      }
    }

    if (!await notifications.canScheduleExact() &&
        !settings.exactPromptShown) {
      if (!mounted) return;
      await settings.markExactPromptShown();
      final ok = await _confirm(
        title: 'Allow exact reminders?',
        message: 'To fire alerts at the exact minute, Android needs '
            '"Alarms & reminders" access. Without it, alerts may arrive a '
            'few minutes late.',
        confirm: 'Open settings',
      );
      if (ok) await notifications.requestExactAlarmPermission();
    }

    await tasks.rescheduleAll();
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirm,
  }) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(confirm)),
        ],
      ),
    );
    return r ?? false;
  }

  List<Task> _apply(List<Task> all, DateTime now) {
    final endOfToday = DateTime(now.year, now.month, now.day + 1);
    final list = all.where((t) {
      switch (_filter) {
        case _Filter.today:
          return isSameDay(t.dueAt, now) ||
              (t.status != TaskStatus.completed && t.dueAt.isBefore(now));
        case _Filter.upcoming:
          return t.status != TaskStatus.completed &&
              !t.dueAt.isBefore(endOfToday);
        case _Filter.completed:
          return t.status == TaskStatus.completed;
        case _Filter.all:
          return true;
      }
    }).toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return list;
  }

  void _showSettings() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _SettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final settings = context.watch<SettingsProvider>();
    final now = DateTime.now();
    final tasks = _apply(provider.tasks, now);
    final leftToday = provider.tasks
        .where((t) =>
            isSameDay(t.dueAt, now) && t.status != TaskStatus.completed)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.tune),
            onPressed: _showSettings,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTaskEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('New task'),
      ),
      body: provider.loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${DateFormat('EEEE, MMM d').format(now)} · '
                      '$leftToday left today',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      for (final f in _Filter.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(f.label),
                            selected: _filter == f,
                            onSelected: (_) => setState(() => _filter = f),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: tasks.isEmpty
                      ? const _EmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                          itemCount: tasks.length,
                          itemBuilder: (_, i) {
                            final t = tasks[i];
                            return _TaskCard(
                              task: t,
                              now: now,
                              state: t.stateAt(now, settings.preAlertMinutes),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.task_alt, size: 64, color: cs.outline),
          const SizedBox(height: 12),
          Text('Nothing here yet', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Tap "New task" to add one.',
              style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.state, required this.now});

  final Task task;
  final DueState state;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = stateColor(state, cs);
    final done = state == DueState.completed;

    final Color bg = switch (state) {
      DueState.dueSoon => Colors.amber.withValues(alpha: 0.22),
      DueState.overdue => cs.errorContainer.withValues(alpha: 0.45),
      _ => cs.surfaceContainerLow,
    };

    final IconData icon = done
        ? Icons.check_circle
        : task.status == TaskStatus.inProgress
            ? Icons.timelapse
            : Icons.radio_button_unchecked;

    return Card(
      elevation: 0,
      color: bg,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: (state == DueState.dueSoon || state == DueState.overdue)
              ? color
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
        leading: IconButton(
          tooltip: done ? 'Mark pending' : 'Mark completed',
          icon: Icon(icon, color: color),
          onPressed: () => context.read<TaskProvider>().setStatus(
                task,
                done ? TaskStatus.pending : TaskStatus.completed,
              ),
        ),
        title: Text(
          task.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: done ? TextDecoration.lineThrough : null,
            color: done ? cs.onSurfaceVariant : null,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${friendlyWhen(task.dueAt, now)} · ${task.category}'),
              Text(
                relativeLabel(task, state, now),
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => TaskDetailScreen(taskId: task.id!))),
      ),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            const Text('Theme'),
            const SizedBox(height: 8),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto),
                    label: Text('System')),
                ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode),
                    label: Text('Light')),
                ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode),
                    label: Text('Dark')),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => settings.setThemeMode(s.first),
            ),
            const SizedBox(height: 20),
            Text('Default "almost due" alert: '
                '${settings.preAlertMinutes} min before'),
            Slider(
              min: 5,
              max: 60,
              divisions: 11,
              label: '${settings.preAlertMinutes} min',
              value: settings.preAlertMinutes.toDouble(),
              onChanged: (v) => settings.setPreAlertMinutes(v.round()),
              onChangeEnd: (_) => context.read<TaskProvider>().rescheduleAll(),
            ),
            Text(
              'Individual tasks can override this when you create or edit them.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
