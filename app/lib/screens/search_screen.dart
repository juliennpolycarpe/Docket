import 'package:flutter/material.dart';

import '../data.dart';
import '../widgets/item_cards.dart';

/// Results for the sidebar search across To Do, Upcoming and Inbox.
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = DataScope.of(context);
    final now = DateTime.now();
    final q = query.toLowerCase();
    bool matches(Iterable<String?> fields) => fields.any((f) => f != null && f.toLowerCase().contains(q));

    final tasks = data.tasks.where((t) => matches([t.title, t.notes, t.courseName])).toList();
    final events = data.events.where((e) => matches([e.title, e.location, e.notes])).toList();
    final inbox = data.inbox.where((i) => matches([i.title, i.summary, i.fromName, i.fromAddress])).toList();

    final sections = [
      if (tasks.isNotEmpty) ('To Do', [for (final t in tasks) TaskCard(task: t, now: now, showPriority: true)]),
      if (events.isNotEmpty) ('Upcoming', [for (final e in events) EventCard(event: e, now: now, showPriority: true)]),
      if (inbox.isNotEmpty) ('Inbox', [for (final i in inbox) InboxCard(item: i, now: now, showPriority: true)]),
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Results for "$query"', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        if (sections.isEmpty)
          Text('Nothing matches.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        for (final (title, cards) in sections) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
          ),
          for (final card in cards) Padding(padding: const EdgeInsets.only(bottom: 8), child: card),
        ],
      ],
    );
  }
}
