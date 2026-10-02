import 'package:flutter/material.dart';

enum Priority {
  high('High', Color(0xFFE5484D)),
  medium('Medium', Color(0xFFF2A93B)),
  low('Low', Color(0xFF46A758));

  const Priority(this.label, this.color);
  final String label;
  final Color color;

  static Priority? parse(Object? value) => switch (value) {
        'high' => Priority.high,
        'medium' => Priority.medium,
        'low' => Priority.low,
        _ => null,
      };

  /// The value stored in the database.
  String get dbValue => name;
}

/// Tasks without a priority get one from their due date:
/// due within 2 days (or overdue) is High, within a week Medium, otherwise Low.
Priority autoTaskPriority(DateTime? dueAt, DateTime now) {
  if (dueAt == null) return Priority.low;
  final left = dueAt.difference(now);
  if (left <= const Duration(days: 2)) return Priority.high;
  if (left <= const Duration(days: 7)) return Priority.medium;
  return Priority.low;
}

/// Events without a priority get one from when they start:
/// today or tomorrow is High, within a week Medium, otherwise Low.
Priority autoEventPriority(DateTime startsAt, DateTime now) {
  final days = calendarDaysBetween(now, startsAt);
  if (days <= 1) return Priority.high;
  if (days <= 7) return Priority.medium;
  return Priority.low;
}

/// Whole calendar days from [from] to [to] (0 = same day), ignoring daylight-saving shifts.
int calendarDaysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
