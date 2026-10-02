import 'package:flutter/material.dart';

import '../data.dart';
import '../format.dart';
import '../greeting.dart';
import '../main.dart';
import '../models/priority.dart';
import '../navigation.dart';
import '../profile.dart';
import '../widgets/item_editor.dart';

const _rowsPerBox = 4;

/// Greeting, "Create new item", and a preview box for each list.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpen});

  final ValueChanged<Destination> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = DataScope.of(context);
    final now = DateTime.now();

    final urgentInbox = data.inbox.where((i) => !i.dismissed && i.effectivePriority == Priority.high).toList()
      ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    final upcoming = data.events.where((e) => e.isUpcoming(now)).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final todo = data.tasks.where((t) => !t.isDone).toList()
      ..sort((a, b) {
        // Soonest first; no due date last.
        if (a.dueAt == null || b.dueAt == null) return (a.dueAt == null ? 1 : 0) - (b.dueAt == null ? 1 : 0);
        return a.dueAt!.compareTo(b.dueAt!);
      });

    final boxes = [
      _SummaryBox(
        title: 'High priority',
        icon: Icons.inbox_outlined,
        total: urgentInbox.length,
        emptyText: 'Nothing urgent in your inbox.',
        onTap: () => onOpen(Destination.inbox),
        rows: [
          for (final item in urgentInbox.take(_rowsPerBox))
            _SummaryRow(
              title: item.title,
              subtitle: [
                item.sender ?? (item.isManual ? 'Added by you' : null),
                if (item.deadline != null) 'Due ${formatDue(item.deadline!, now)}',
              ].nonNulls.join(' · '),
              dot: Priority.high.color,
            ),
        ],
      ),
      _SummaryBox(
        title: 'Upcoming events',
        icon: Icons.event_outlined,
        total: upcoming.length,
        emptyText: 'No upcoming events.',
        onTap: () => onOpen(Destination.upcoming),
        rows: [
          for (final event in upcoming.take(_rowsPerBox))
            _SummaryRow(title: event.title, subtitle: formatEventTime(event, now), dot: event.effectivePriority(now).color),
        ],
      ),
      _SummaryBox(
        title: 'To Do',
        icon: Icons.check_circle_outline,
        total: todo.length,
        emptyText: 'All caught up.',
        onTap: () => onOpen(Destination.todo),
        rows: [
          for (final task in todo.take(_rowsPerBox))
            _SummaryRow(
              title: task.title,
              subtitle: [if (task.courseName != null) task.courseName!, if (task.dueAt != null) formatDue(task.dueAt!, now)].join(' · '),
              subtitleColor: task.isOverdue(now) ? theme.colorScheme.error : null,
              dot: task.effectivePriority(now).color,
            ),
        ],
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: wide ? 40 : 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.checklist_rounded, size: wide ? 40 : 30, color: theme.colorScheme.primary),
                      const SizedBox(width: 14),
                      Flexible(
                        child: Text(
                          greeting(now, firstName(supabase.auth.currentUser)),
                          textAlign: TextAlign.center,
                          style: (wide ? theme.textTheme.displaySmall : theme.textTheme.headlineMedium)?.copyWith(
                            fontFamily: 'Georgia',
                            fontFamilyFallback: const ['serif'],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: wide ? 40 : 24),
                  _CreateNewItemButton(onTap: () => showNewItemEditor(context)),
                  const SizedBox(height: 16),
                  if (data.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text("Couldn't load everything. Check your connection.",
                          style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  if (wide)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < boxes.length; i++) ...[
                            if (i > 0) const SizedBox(width: 16),
                            Expanded(child: boxes[i]),
                          ],
                        ],
                      ),
                    )
                  else
                    for (final box in boxes) Padding(padding: const EdgeInsets.only(bottom: 16), child: box),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CreateNewItemButton extends StatelessWidget {
  const _CreateNewItemButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: theme.brightness == Brightness.dark ? scheme.surfaceContainerHighest : scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 104,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: scheme.primary,
                child: Icon(Icons.add, color: scheme.onPrimary),
              ),
              const SizedBox(width: 14),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Create new item', style: theme.textTheme.titleLarge),
                  Text('A to-do, an event, or something for your inbox',
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow {
  const _SummaryRow({required this.title, required this.subtitle, this.dot, this.subtitleColor});
  final String title;
  final String subtitle;
  final Color? dot;
  final Color? subtitleColor;
}

class _SummaryBox extends StatelessWidget {
  const _SummaryBox({
    required this.title,
    required this.icon,
    required this.total,
    required this.rows,
    required this.emptyText,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final int total;
  final List<_SummaryRow> rows;
  final String emptyText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 220),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: scheme.primary),
                    const SizedBox(width: 8),
                    Flexible(child: Text(title, style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    if (total > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(10)),
                        child: Text('$total', style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSecondaryContainer)),
                      ),
                    const Spacer(),
                    Icon(Icons.arrow_forward, size: 18, color: scheme.onSurfaceVariant),
                  ],
                ),
                const SizedBox(height: 12),
                if (rows.isEmpty) Text(emptyText, style: muted),
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6, right: 10),
                          child: CircleAvatar(radius: 4, backgroundColor: row.dot ?? scheme.outline),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(row.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                              if (row.subtitle.isNotEmpty)
                                Text(row.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: muted?.copyWith(color: row.subtitleColor)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (total > rows.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('+${total - rows.length} more', style: theme.textTheme.labelMedium?.copyWith(color: scheme.primary)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
