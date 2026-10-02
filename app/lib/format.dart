import 'package:intl/intl.dart';

import 'models/event.dart';
import 'models/priority.dart';

/// "Today", "Tomorrow", "Yesterday", "Friday", "Oct 14", "Jan 5, 2027"
String dayLabel(DateTime day, DateTime now) {
  final days = calendarDaysBetween(now, day);
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  if (days == -1) return 'Yesterday';
  if (days > 1 && days < 7) return DateFormat.EEEE().format(day);
  return day.year == now.year ? DateFormat.MMMd().format(day) : DateFormat.yMMMd().format(day);
}

String timeLabel(DateTime time) => DateFormat.jm().format(time);

/// "Today, 11:59 PM", "Friday, 5:00 PM", "Oct 14, 11:59 PM"
String formatDue(DateTime due, DateTime now) => '${dayLabel(due, now)}, ${timeLabel(due)}';

/// "Today, 3:00 PM – 4:30 PM", "Friday, All day", "Oct 14, 9:00 AM"
String formatEventTime(Event event, DateTime now) {
  final day = dayLabel(event.startsAt, now);
  if (event.allDay) return '$day, All day';
  final end = event.endsAt;
  final sameDay = end != null && calendarDaysBetween(event.startsAt, end) == 0;
  if (end == null) return '$day, ${timeLabel(event.startsAt)}';
  if (sameDay) return '$day, ${timeLabel(event.startsAt)} – ${timeLabel(end)}';
  return '$day, ${timeLabel(event.startsAt)} – ${formatDue(end, now)}';
}
