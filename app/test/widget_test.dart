import 'package:docket/format.dart';
import 'package:docket/greeting.dart';
import 'package:docket/models/event.dart';
import 'package:docket/models/priority.dart';
import 'package:docket/models/task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 1, 12); // Thursday noon

  test('tasks get an automatic priority from their due date', () {
    expect(autoTaskPriority(DateTime(2026, 9, 30), now), Priority.high, reason: 'overdue');
    expect(autoTaskPriority(DateTime(2026, 10, 3, 11), now), Priority.high, reason: 'within 2 days');
    expect(autoTaskPriority(DateTime(2026, 10, 6), now), Priority.medium, reason: 'within a week');
    expect(autoTaskPriority(DateTime(2026, 10, 20), now), Priority.low);
    expect(autoTaskPriority(null, now), Priority.low);
  });

  test('a priority you set wins over the automatic one', () {
    final task = Task(id: '1', source: 'manual', title: 'x', dueAt: DateTime(2026, 9, 30), priority: Priority.low);
    expect(task.effectivePriority(now), Priority.low);
  });

  test('events get an automatic priority from their start', () {
    expect(autoEventPriority(DateTime(2026, 10, 2, 23), now), Priority.high, reason: 'tomorrow');
    expect(autoEventPriority(DateTime(2026, 10, 7), now), Priority.medium);
    expect(autoEventPriority(DateTime(2026, 11, 1), now), Priority.low);
  });

  test('events stay upcoming until they end', () {
    Event event({required DateTime start, DateTime? end, bool allDay = false}) =>
        Event(id: '1', title: 'x', startsAt: start, endsAt: end, allDay: allDay);
    expect(event(start: DateTime(2026, 10, 1, 11), end: DateTime(2026, 10, 1, 13)).isUpcoming(now), isTrue);
    expect(event(start: DateTime(2026, 10, 1, 9), end: DateTime(2026, 10, 1, 10)).isUpcoming(now), isFalse);
    expect(event(start: DateTime(2026, 10, 1), allDay: true).isUpcoming(now), isTrue);
    expect(event(start: DateTime(2026, 9, 30), allDay: true).isUpcoming(now), isFalse);
  });

  test('greeting depends on the time of day and includes the name', () {
    expect(greeting(DateTime(2026, 10, 1, 1), 'Julien'), endsWith(', Julien?'));
    expect(greeting(DateTime(2026, 10, 1, 9), 'Julien'), contains('Julien'));
    expect(greeting(DateTime(2026, 10, 1, 9), null), isNot(contains(',')));
    expect(greeting(DateTime(2026, 10, 1, 2), 'Julien'), greeting(DateTime(2026, 10, 1, 3), 'Julien'),
        reason: 'stays the same within the same part of the day');
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
