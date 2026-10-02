import 'package:flutter/material.dart';

import '../data.dart';
import '../widgets/item_cards.dart';
import '../widgets/item_editor.dart';
import '../widgets/priority_board.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  bool _showDone = false;

  @override
  Widget build(BuildContext context) {
    final data = DataScope.of(context);
    final now = DateTime.now();
    final open = data.inbox.where((i) => !i.dismissed).length;
    final items = data.inbox.where((i) => _showDone || !i.dismissed).toList()
      ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Inbox',
          subtitle: '$open open · Emails sorted by Claude, plus your own items',
          actions: [
            FilterChip(
              label: const Text('Show done'),
              selected: _showDone,
              onSelected: (v) => setState(() => _showDone = v),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => showNewItemEditor(context, kind: ItemKind.inbox),
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
            ),
          ],
        ),
        Expanded(
          child: data.isLoading
              ? const Center(child: CircularProgressIndicator())
              : PriorityBoard(
                  items: items,
                  priorityOf: (i) => i.effectivePriority,
                  cardBuilder: (i) => InboxCard(item: i, now: now),
                ),
        ),
      ],
    );
  }
}
