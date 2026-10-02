/// The home page greeting, which depends on the time of day. The same one is
/// shown all day for a given time of day, so it doesn't change on every refresh.
String greeting(DateTime now, String? name) {
  String say(String text, {String end = ''}) => name == null ? '$text$end' : '$text, $name$end';

  final options = switch (now.hour) {
    >= 5 && < 12 => [say('Good morning'), say('Morning'), say('Rise and shine')],
    >= 12 && < 17 => [say('Good afternoon'), say('Afternoon'), say('Back at it')],
    >= 17 && < 22 => [say('Good evening'), say('Evening'), say('Winding down', end: '?')],
    _ => [
        say('Late night study session', end: '?'),
        say('Burning the midnight oil', end: '?'),
        say('Still up', end: '?'),
      ],
  };
  final dayOfYear = now.difference(DateTime(now.year)).inDays;
  return options[dayOfYear % options.length];
}
