import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/task.dart';
import '../utils.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  static const _dueSoonChannel = AndroidNotificationChannel(
    'due_soon',
    'Almost due',
    description: 'Heads-up shortly before a task is due',
    importance: Importance.high,
  );
  static const _dueChannel = AndroidNotificationChannel(
    'task_due',
    'Task due',
    description: 'Alert at the exact due time of a task',
    importance: Importance.max,
  );

  // Two notification IDs per task.
  int _preId(int taskId) => taskId * 2;
  int _dueId(int taskId) => taskId * 2 + 1;

  Future<void> init({required void Function(int taskId) onTaskTapped}) async {
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (e) {
      debugPrint('Timezone lookup failed, falling back to UTC: $e');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (r) {
        final id = int.tryParse(r.payload ?? '');
        if (id != null) onTaskTapped(id);
      },
    );

    await _android?.createNotificationChannel(_dueSoonChannel);
    await _android?.createNotificationChannel(_dueChannel);
  }

  /// Task id if the app was cold-started by tapping a notification.
  Future<int?> launchTaskId() async {
    final d = await _plugin.getNotificationAppLaunchDetails();
    if (d?.didNotificationLaunchApp ?? false) {
      return int.tryParse(d!.notificationResponse?.payload ?? '');
    }
    return null;
  }

  // ---- Permissions ----
  Future<bool> notificationsEnabled() async =>
      await _android?.areNotificationsEnabled() ?? true;

  /// Shows the Android 13+ POST_NOTIFICATIONS system prompt.
  Future<bool> requestNotificationPermission() async =>
      await _android?.requestNotificationsPermission() ?? true;

  Future<bool> canScheduleExact() async =>
      await _android?.canScheduleExactNotifications() ?? false;

  /// Android 12+: opens the "Alarms & reminders" settings page.
  Future<bool> requestExactAlarmPermission() async =>
      await _android?.requestExactAlarmsPermission() ?? false;

  // ---- Scheduling ----
  NotificationDetails _details(AndroidNotificationChannel c) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          c.id,
          c.name,
          channelDescription: c.description,
          importance: c.importance,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
        ),
      );

  Future<void> scheduleTask(Task task, int defaultPreAlert) async {
    final id = task.id;
    if (id == null) return;
    await cancelTask(id);
    if (task.status == TaskStatus.completed) return;

    final now = DateTime.now();
    final mode = await canScheduleExact()
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    final pre = task.preAlertMinutes ?? defaultPreAlert;
    final preAt = task.dueAt.subtract(Duration(minutes: pre));
    if (pre > 0 && preAt.isAfter(now)) {
      await _plugin.zonedSchedule(
        _preId(id),
        'Almost due: ${task.title}',
        'Due in $pre minutes (at ${formatTime(task.dueAt)})',
        tz.TZDateTime.from(preAt, tz.local),
        _details(_dueSoonChannel),
        androidScheduleMode: mode,
        payload: '$id',
      );
    }

    if (task.dueAt.isAfter(now)) {
      await _plugin.zonedSchedule(
        _dueId(id),
        'Due now: ${task.title}',
        task.description.isEmpty ? 'This task is due.' : task.description,
        tz.TZDateTime.from(task.dueAt, tz.local),
        _details(_dueChannel),
        androidScheduleMode: mode,
        payload: '$id',
      );
    }
  }

  Future<void> cancelTask(int taskId) async {
    await _plugin.cancel(_preId(taskId));
    await _plugin.cancel(_dueId(taskId));
  }

  Future<void> rescheduleAll(List<Task> tasks, int defaultPreAlert) async {
    for (final t in tasks) {
      await scheduleTask(t, defaultPreAlert);
    }
  }
}
