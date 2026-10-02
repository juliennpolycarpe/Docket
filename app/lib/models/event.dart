import 'priority.dart';

class Event {
  Event({
    required this.id,
    required this.title,
    required this.startsAt,
    this.accountId,
    this.endsAt,
    this.allDay = false,
    this.location,
    this.notes,
    this.url,
    this.priority,
  });

  factory Event.fromRow(Map<String, dynamic> row) => Event(
        id: row['id'] as String,
        accountId: row['account_id'] as String?,
        title: row['title'] as String,
        startsAt: DateTime.parse(row['starts_at'] as String).toLocal(),
        endsAt: row['ends_at'] == null ? null : DateTime.parse(row['ends_at'] as String).toLocal(),
        allDay: row['all_day'] as bool? ?? false,
        location: row['location'] as String?,
        notes: row['notes'] as String?,
        url: row['url'] as String?,
        priority: Priority.parse(row['priority']),
      );

  final String id;
  final String? accountId; // null = added in Docket
  final String title;
  final DateTime startsAt;
  final DateTime? endsAt;
  final bool allDay;
  final String? location;
  final String? notes;
  final String? url;
  final Priority? priority; // null = automatic

  bool get isManual => accountId == null;
  Priority effectivePriority(DateTime now) => priority ?? autoEventPriority(startsAt, now);

  /// Still worth showing: hasn't ended yet (all-day and open-ended events count until the day is over).
  bool isUpcoming(DateTime now) {
    final end = endsAt;
    if (end != null && !allDay) return end.isAfter(now);
    return calendarDaysBetween(now, startsAt) >= 0;
  }
}
