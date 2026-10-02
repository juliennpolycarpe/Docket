import 'package:flutter/material.dart';

import '../data.dart';
import '../widgets/item_cards.dart';
import '../widgets/item_editor.dart';
import '../widgets/priority_board.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = DataScope.of(context);
    final now = DateTime.now();
    final events = data.events.where((e) => e.isUpcoming(now)).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Upcoming',
          subtitle: '${events.length} upcoming · Outlook, Google Calendar and your own events',
          actions: [
            FilledButton.icon(
              onPressed: () => showNewItemEditor(context, kind: ItemKind.event),
              icon: const Icon(Icons.add),
              label: const Text('Add event'),
            ),
          ],
        ),
        Expanded(
          child: data.isLoading
              ? const Center(child: CircularProgressIndicator())
              : PriorityBoard(
                  items: events,
                  priorityOf: (e) => e.effectivePriority(now),
                  cardBuilder: (e) => EventCard(event: e, now: now),
                ),
        ),
      ],
    );
  }
}
