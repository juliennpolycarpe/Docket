import 'package:docket/models/task.dart';
import 'package:docket/screens/todo_screen.dart';
import 'package:flutter_test/flutter_test.dart';

Task _task(String title, {DateTime? due, bool completed = false, bool submitted = false}) =>
    Task(id: title, source: 'manual', title: title, dueAt: due, completed: completed, submitted: submitted);

void main() {
  final now = DateTime(2026, 10, 1, 12); // Thursday noon

  test('groupTasks puts tasks in the right sections', () {
    final groups = groupTasks([
      _task('overdue', due: DateTime(2026, 9, 30, 23, 59)),
      _task('tonight', due: DateTime(2026, 10, 1, 23, 59)),
      _task('monday', due: DateTime(2026, 10, 5, 9)),
      _task('next month', due: DateTime(2026, 11, 2)),
      _task('someday'),
      _task('checked off', due: DateTime(2026, 10, 2), completed: true),
      _task('submitted', due: DateTime(2026, 9, 1), submitted: true),
    ], now);

    List<String> titles(TaskSection s) => groups[s]!.map((t) => t.title).toList();
    expect(titles(TaskSection.overdue), ['overdue']);
    expect(titles(TaskSection.today), ['tonight']);
    expect(titles(TaskSection.thisWeek), ['monday']);
    expect(titles(TaskSection.later), ['next month']);
    expect(titles(TaskSection.noDate), ['someday']);
    expect(titles(TaskSection.done), ['checked off', 'submitted']);
  });

  test('sections are sorted soonest first', () {
    final groups = groupTasks([
      _task('b', due: DateTime(2026, 10, 4)),
      _task('a', due: DateTime(2026, 10, 3)),
    ], now);
    expect(groups[TaskSection.thisWeek]!.map((t) => t.title), ['a', 'b']);
  });

  test('formatDue uses friendly day names', () {
    // intl puts a narrow no-break space before AM/PM.
    String due(DateTime d) => formatDue(d, now).replaceAll(' ', ' ');
    expect(due(DateTime(2026, 10, 1, 23, 59)), 'Today, 11:59 PM');
    expect(due(DateTime(2026, 10, 2, 9)), 'Tomorrow, 9:00 AM');
    expect(due(DateTime(2026, 10, 5, 17)), 'Monday, 5:00 PM');
    expect(due(DateTime(2026, 10, 14, 23, 59)), 'Oct 14, 11:59 PM');
    expect(due(DateTime(2027, 1, 5, 8)), 'Jan 5, 2027, 8:00 AM');
  });
}
