import 'priority.dart';

class Task {
  Task({
    required this.id,
    required this.source,
    required this.title,
    this.notes,
    this.courseName,
    this.dueAt,
    this.url,
    this.priority,
    this.submitted = false,
    this.completed = false,
  });

  factory Task.fromRow(Map<String, dynamic> row) => Task(
        id: row['id'] as String,
        source: row['source'] as String,
        title: row['title'] as String,
        notes: row['notes'] as String?,
        courseName: row['course_name'] as String?,
        dueAt: row['due_at'] == null ? null : DateTime.parse(row['due_at'] as String).toLocal(),
        url: row['url'] as String?,
        priority: Priority.parse(row['priority']),
        submitted: row['submitted'] as bool? ?? false,
        completed: row['completed'] as bool? ?? false,
      );

  final String id;
  final String source; // 'manual' or 'canvas'
  final String title;
  final String? notes;
  final String? courseName;
  final DateTime? dueAt;
  final String? url;
  final Priority? priority; // null = automatic
  final bool submitted; // submitted (or marked done) in Canvas
  final bool completed; // checked off in Docket

  bool get isDone => completed || submitted;
  bool get isManual => source == 'manual';
  bool isOverdue(DateTime now) => !isDone && dueAt != null && dueAt!.isBefore(now);
  Priority effectivePriority(DateTime now) => priority ?? autoTaskPriority(dueAt, now);
}
