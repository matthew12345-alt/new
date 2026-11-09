import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'models/task.dart';

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String formatTime(DateTime d) => DateFormat('h:mm a').format(d);

String formatDateTime(DateTime d) => DateFormat('EEE, MMM d · h:mm a').format(d);

String friendlyWhen(DateTime d, DateTime now) {
  if (isSameDay(d, now)) return 'Today, ${formatTime(d)}';
  if (isSameDay(d, now.add(const Duration(days: 1)))) {
    return 'Tomorrow, ${formatTime(d)}';
  }
  if (isSameDay(d, now.subtract(const Duration(days: 1)))) {
    return 'Yesterday, ${formatTime(d)}';
  }
  return formatDateTime(d);
}

/// Long countdown, e.g. "2h 14m 05s".
String formatCountdown(Duration d) {
  d = d.abs();
  final days = d.inDays;
  final h = d.inHours % 24;
  final m = d.inMinutes % 60;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  if (days > 0) return '${days}d ${h}h ${m}m';
  if (d.inHours > 0) return '${h}h ${m}m ${s}s';
  return '${m}m ${s}s';
}

/// Short duration, e.g. "3h 20m".
String shortDuration(Duration d) {
  d = d.abs();
  if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
  if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
  return '${d.inMinutes < 1 ? 1 : d.inMinutes}m';
}

String relativeLabel(Task t, DueState s, DateTime now) {
  switch (s) {
    case DueState.completed:
      return 'Completed';
    case DueState.overdue:
      return 'Overdue by ${shortDuration(now.difference(t.dueAt))}';
    case DueState.dueSoon:
      return 'Due soon · in ${shortDuration(t.dueAt.difference(now))}';
    case DueState.upcoming:
      return 'In ${shortDuration(t.dueAt.difference(now))}';
  }
}

Color stateColor(DueState s, ColorScheme cs) {
  switch (s) {
    case DueState.completed:
      return Colors.green;
    case DueState.overdue:
      return cs.error;
    case DueState.dueSoon:
      return Colors.amber.shade800;
    case DueState.upcoming:
      return cs.primary;
  }
}

String preAlertLabel(int? minutes, int defaultMinutes) {
  if (minutes == null) return 'Default ($defaultMinutes min before)';
  if (minutes == 0) return 'Off';
  return '$minutes min before';
}
