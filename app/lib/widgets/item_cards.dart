import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import '../format.dart';
import '../models/event.dart';
import '../models/inbox_item.dart';
import '../models/priority.dart';
import '../models/task.dart';
import 'item_editor.dart';

// Cards for the priority boards and search results. Things you added yourself
// open the editor when tapped; synced things open in their original app.

class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task, required this.now, this.showPriority = false});

  final Task task;
  final DateTime now;
  final bool showPriority;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = [
      if (task.courseName != null) task.courseName!,
      if (task.dueAt != null) formatDue(task.dueAt!, now),
      if (task.submitted) 'Submitted in Canvas',
    ].join(' · ');

    return _ItemCard(
      onTap: task.isManual ? () => showTaskEditor(context, task) : _opener(task.url),
      leading: Checkbox(
        value: task.isDone,
        visualDensity: VisualDensity.compact,
        onChanged: task.submitted
            ? null
            : (value) => saveOrComplain(context, () => updateRow('tasks', task.id, {'completed': value ?? false})),
      ),
      title: task.title,
      done: task.isDone,
      lines: [
        if (details.isNotEmpty)
          Text(details, style: task.isOverdue(now) ? TextStyle(color: theme.colorScheme.error) : null),
      ],
      priority: showPriority ? task.effectivePriority(now) : null,
      menu: ItemMenu(
        priority: task.priority,
        allowAutomatic: true,
        onPriority: (p) => saveOrComplain(context, () => updateRow('tasks', task.id, {'priority': p?.dbValue})),
        openLabel: 'Open in Canvas',
        url: task.url,
        onEdit: task.isManual ? () => showTaskEditor(context, task) : null,
        onDelete: task.isManual ? () => _confirmAndDelete(context, 'tasks', task.id, task.title) : null,
      ),
    );
  }
}

class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, required this.now, this.showPriority = false});

  final Event event;
  final DateTime now;
  final bool showPriority;

  @override
  Widget build(BuildContext context) {
    return _ItemCard(
      onTap: event.isManual ? () => showEventEditor(context, event) : _opener(event.url),
      leading: const Padding(
        padding: EdgeInsets.all(12),
        child: Icon(Icons.event_outlined, size: 20),
      ),
      title: event.title,
      lines: [
        Text(formatEventTime(event, now)),
        if (event.location != null) Text(event.location!),
      ],
      priority: showPriority ? event.effectivePriority(now) : null,
      menu: ItemMenu(
        priority: event.priority,
        allowAutomatic: true,
        onPriority: (p) => saveOrComplain(context, () => updateRow('events', event.id, {'priority': p?.dbValue})),
        openLabel: 'Open in calendar',
        url: event.url,
        onEdit: event.isManual ? () => showEventEditor(context, event) : null,
        onDelete: event.isManual ? () => _confirmAndDelete(context, 'events', event.id, event.title) : null,
      ),
    );
  }
}

class InboxCard extends StatelessWidget {
  const InboxCard({super.key, required this.item, required this.now, this.showPriority = false});

  final InboxItem item;
  final DateTime now;
  final bool showPriority;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant);
    final source = [
      item.sender ?? (item.isManual ? 'Added by you' : null),
      if (item.deadline != null) 'Due ${formatDue(item.deadline!, now)}',
    ].nonNulls.join(' · ');

    return _ItemCard(
      onTap: item.isManual ? () => showInboxEditor(context, item) : _opener(item.url),
      leading: Tooltip(
        message: item.dismissed ? 'Mark as not done' : 'Mark as done',
        child: Checkbox(
          value: item.dismissed,
          visualDensity: VisualDensity.compact,
          onChanged: (value) =>
              saveOrComplain(context, () => updateRow('inbox_items', item.id, {'dismissed': value ?? false})),
        ),
      ),
      title: item.title,
      done: item.dismissed,
      lines: [
        if (source.isNotEmpty) Text(source),
        if (item.summary != null) Text(item.summary!, maxLines: 3, overflow: TextOverflow.ellipsis),
        if (item.priorityReason != null)
          Text(item.priorityReason!, style: muted.copyWith(fontStyle: FontStyle.italic)),
      ],
      priority: showPriority ? item.effectivePriority : null,
      menu: ItemMenu(
        priority: item.priority,
        allowAutomatic: false,
        onPriority: (p) => saveOrComplain(context, () => updateRow('inbox_items', item.id, {'priority': p?.dbValue})),
        openLabel: 'Open email',
        url: item.url,
        onEdit: item.isManual ? () => showInboxEditor(context, item) : null,
        onDelete: item.isManual ? () => _confirmAndDelete(context, 'inbox_items', item.id, item.title) : null,
      ),
    );
  }
}

VoidCallback? _opener(String? url) => url == null ? null : () => launchUrl(Uri.parse(url));

Future<void> _confirmAndDelete(BuildContext context, String table, String id, String title) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete "$title"?'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    await saveOrComplain(context, () => deleteRow(table, id), failure: "Couldn't delete that. Try again.");
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.leading,
    required this.title,
    required this.lines,
    required this.menu,
    this.onTap,
    this.done = false,
    this.priority,
  });

  final Widget leading;
  final String title;
  final List<Widget> lines;
  final Widget menu;
  final VoidCallback? onTap;
  final bool done;
  final Priority? priority;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: theme.brightness == Brightness.dark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 0, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leading,
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          decoration: done ? TextDecoration.lineThrough : null,
                          color: done ? scheme.onSurfaceVariant : null,
                        ),
                      ),
                      DefaultTextStyle.merge(
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [for (final line in lines) Padding(padding: const EdgeInsets.only(top: 3), child: line)],
                        ),
                      ),
                      if (priority != null) ...[
                        const SizedBox(height: 6),
                        PriorityTag(priority: priority!),
                      ],
                    ],
                  ),
                ),
              ),
              menu,
            ],
          ),
        ),
      ),
    );
  }
}

class PriorityTag extends StatelessWidget {
  const PriorityTag({super.key, required this.priority});

  final Priority priority;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(radius: 4, backgroundColor: priority.color),
        const SizedBox(width: 6),
        Text('${priority.label} priority', style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

/// The ⋮ menu on a card: change priority, open, edit, delete.
class ItemMenu extends StatelessWidget {
  const ItemMenu({
    super.key,
    required this.priority,
    required this.allowAutomatic,
    required this.onPriority,
    required this.openLabel,
    this.url,
    this.onEdit,
    this.onDelete,
  });

  final Priority? priority; // the stored priority; null = automatic
  final bool allowAutomatic;
  final ValueChanged<Priority?> onPriority;
  final String openLabel;
  final String? url;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: const Icon(Icons.more_vert, size: 20),
      onSelected: (value) {
        switch (value) {
          case 'auto':
            onPriority(null);
          case 'open':
            launchUrl(Uri.parse(url!));
          case 'edit':
            onEdit?.call();
          case 'delete':
            onDelete?.call();
          default:
            onPriority(Priority.values.byName(value));
        }
      },
      itemBuilder: (context) => [
        if (allowAutomatic)
          CheckedPopupMenuItem(value: 'auto', checked: priority == null, child: const Text('Automatic priority')),
        for (final p in Priority.values)
          CheckedPopupMenuItem(value: p.name, checked: priority == p, child: Text('${p.label} priority')),
        if (url != null || onEdit != null || onDelete != null) const PopupMenuDivider(),
        if (url != null) PopupMenuItem(value: 'open', child: Text(openLabel)),
        if (onEdit != null) const PopupMenuItem(value: 'edit', child: Text('Edit')),
        if (onDelete != null) const PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }
}
