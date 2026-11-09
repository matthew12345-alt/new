enum TaskStatus {
  pending('Pending'),
  inProgress('In Progress'),
  completed('Completed');

  const TaskStatus(this.label);
  final String label;
}

enum DueState { completed, overdue, dueSoon, upcoming }

class Task {
  const Task({
    this.id,
    required this.title,
    this.description = '',
    this.category = 'General',
    required this.dueAt,
    this.status = TaskStatus.pending,
    this.preAlertMinutes,
    required this.createdAt,
  });

  final int? id;
  final String title;
  final String description;
  final String category;
  final DateTime dueAt;
  final TaskStatus status;

  /// null = use the app-wide default; 0 = no pre-alert.
  final int? preAlertMinutes;
  final DateTime createdAt;

  Task copyWith({
    int? id,
    String? title,
    String? description,
    String? category,
    DateTime? dueAt,
    TaskStatus? status,
    int? preAlertMinutes,
    bool clearPreAlert = false,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      dueAt: dueAt ?? this.dueAt,
      status: status ?? this.status,
      preAlertMinutes:
          clearPreAlert ? null : (preAlertMinutes ?? this.preAlertMinutes),
      createdAt: createdAt,
    );
  }

  DueState stateAt(DateTime now, int defaultPreAlert) {
    if (status == TaskStatus.completed) return DueState.completed;
    if (!dueAt.isAfter(now)) return DueState.overdue;
    final pre = preAlertMinutes ?? defaultPreAlert;
    if (pre > 0 && dueAt.difference(now) <= Duration(minutes: pre)) {
      return DueState.dueSoon;
    }
    return DueState.upcoming;
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'description': description,
        'category': category,
        'due_at': dueAt.millisecondsSinceEpoch,
        'status': status.index,
        'pre_alert_minutes': preAlertMinutes,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Task.fromMap(Map<String, Object?> m) => Task(
        id: m['id'] as int?,
        title: m['title'] as String,
        description: (m['description'] as String?) ?? '',
        category: (m['category'] as String?) ?? 'General',
        dueAt: DateTime.fromMillisecondsSinceEpoch(m['due_at'] as int),
        status: TaskStatus.values[m['status'] as int],
        preAlertMinutes: m['pre_alert_minutes'] as int?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );
}

class TaskNote {
  const TaskNote({
    this.id,
    required this.taskId,
    required this.content,
    required this.noteTime,
    required this.createdAt,
  });

  final int? id;
  final int taskId;
  final String content;

  /// The user-chosen moment this note refers to.
  final DateTime noteTime;
  final DateTime createdAt;

  TaskNote copyWith({String? content, DateTime? noteTime}) => TaskNote(
        id: id,
        taskId: taskId,
        content: content ?? this.content,
        noteTime: noteTime ?? this.noteTime,
        createdAt: createdAt,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'task_id': taskId,
        'content': content,
        'note_time': noteTime.millisecondsSinceEpoch,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory TaskNote.fromMap(Map<String, Object?> m) => TaskNote(
        id: m['id'] as int?,
        taskId: m['task_id'] as int,
        content: m['content'] as String,
        noteTime: DateTime.fromMillisecondsSinceEpoch(m['note_time'] as int),
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );
}
