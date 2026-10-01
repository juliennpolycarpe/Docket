class Task {
  Task({
    required this.id,
    required this.source,
    required this.title,
    this.notes,
    this.courseName,
    this.dueAt,
    this.url,
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
  final bool submitted; // submitted (or marked done) in Canvas
  final bool completed; // checked off in Docket

  bool get isDone => completed || submitted;
  bool get isManual => source == 'manual';
}

enum TaskSection {
  overdue('Overdue'),
  today('Today'),
  thisWeek('Next 7 days'),
  later('Later'),
  noDate('No due date'),
  done('Done');

  const TaskSection(this.label);
  final String label;
}

/// Splits tasks into the sections shown on the To Do tab, each sorted by due date.
Map<TaskSection, List<Task>> groupTasks(Iterable<Task> tasks, DateTime now) {
  final startOfTomorrow = DateTime(now.year, now.month, now.day + 1);
  final weekOut = DateTime(now.year, now.month, now.day + 8);

  TaskSection sectionFor(Task task) {
    final due = task.dueAt;
    if (task.isDone) return TaskSection.done;
    if (due == null) return TaskSection.noDate;
    if (due.isBefore(now)) return TaskSection.overdue;
    if (due.isBefore(startOfTomorrow)) return TaskSection.today;
    if (due.isBefore(weekOut)) return TaskSection.thisWeek;
    return TaskSection.later;
  }

  final groups = {for (final section in TaskSection.values) section: <Task>[]};
  for (final task in tasks) {
    groups[sectionFor(task)]!.add(task);
  }
  for (final entry in groups.entries) {
    entry.value.sort((a, b) {
      final ad = a.dueAt, bd = b.dueAt;
      if (ad == null || bd == null) return a.title.compareTo(b.title);
      // Most recent first for Done, soonest first everywhere else.
      return entry.key == TaskSection.done ? bd.compareTo(ad) : ad.compareTo(bd);
    });
  }
  return groups;
}
