import 'dart:math';

import 'package:flutter/material.dart';

import '../models/priority.dart';

/// High / Medium / Low columns. Side by side when there's room; on narrow
/// screens the columns scroll sideways.
class PriorityBoard<T> extends StatelessWidget {
  const PriorityBoard({
    super.key,
    required this.items,
    required this.priorityOf,
    required this.cardBuilder,
  });

  final List<T> items;
  final Priority Function(T) priorityOf;
  final Widget Function(T) cardBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = [
          for (final p in Priority.values)
            _Column(priority: p, cards: [for (final item in items) if (priorityOf(item) == p) cardBuilder(item)]),
        ];
        if (constraints.maxWidth >= 840) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < columns.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: columns[i]),
                ],
              ],
            ),
          );
        }
        final width = min(320.0, constraints.maxWidth - 48);
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: columns.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) => SizedBox(width: width, child: columns[i]),
        );
      },
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.priority, required this.cards});

  final Priority priority;
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                CircleAvatar(radius: 5, backgroundColor: priority.color),
                const SizedBox(width: 8),
                Text(priority.label, style: theme.textTheme.titleSmall),
                const SizedBox(width: 8),
                Text('${cards.length}', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Expanded(
            child: cards.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Nothing here', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    itemCount: cards.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => cards[i],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Title row at the top of each list page.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle, this.actions = const []});

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 8,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: theme.textTheme.headlineSmall),
              if (subtitle != null)
                Text(subtitle!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
          Row(mainAxisSize: MainAxisSize.min, children: actions),
        ],
      ),
    );
  }
}
