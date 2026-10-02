import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data.dart';
import '../main.dart';
import '../models/event.dart';
import '../models/inbox_item.dart';
import '../models/priority.dart';
import '../models/task.dart';

enum ItemKind {
  todo('To Do', Icons.check_circle_outline),
  event('Event', Icons.event_outlined),
  inbox('Inbox', Icons.inbox_outlined);

  const ItemKind(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// "Create new item": pick To Do, Event or Inbox, then fill it in.
Future<void> showNewItemEditor(BuildContext context, {ItemKind kind = ItemKind.todo}) =>
    showDialog(context: context, builder: (_) => ItemEditor(kind: kind));

Future<void> showTaskEditor(BuildContext context, Task task) =>
    showDialog(context: context, builder: (_) => ItemEditor(kind: ItemKind.todo, task: task));

Future<void> showEventEditor(BuildContext context, Event event) =>
    showDialog(context: context, builder: (_) => ItemEditor(kind: ItemKind.event, event: event));

Future<void> showInboxEditor(BuildContext context, InboxItem item) =>
    showDialog(context: context, builder: (_) => ItemEditor(kind: ItemKind.inbox, inboxItem: item));

class ItemEditor extends StatefulWidget {
  const ItemEditor({super.key, required this.kind, this.task, this.event, this.inboxItem});

  final ItemKind kind;
  final Task? task;
  final Event? event;
  final InboxItem? inboxItem;

  bool get isEditing => task != null || event != null || inboxItem != null;

  @override
  State<ItemEditor> createState() => _ItemEditorState();
}

DateTime _nextHour() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, now.hour + 1);
}

class _ItemEditorState extends State<ItemEditor> {
  late ItemKind _kind = widget.kind;
  late final _title = TextEditingController(text: widget.task?.title ?? widget.event?.title ?? widget.inboxItem?.title);
  late final _notes = TextEditingController(text: widget.task?.notes ?? widget.event?.notes ?? widget.inboxItem?.summary);
  late final _location = TextEditingController(text: widget.event?.location);
  late Priority? _priority = widget.task?.priority ??
      widget.event?.priority ??
      widget.inboxItem?.priority ??
      (widget.kind == ItemKind.inbox ? Priority.medium : null);
  late DateTime? _dueAt = widget.task?.dueAt ?? widget.inboxItem?.deadline; // To Do due date / Inbox deadline
  late DateTime _startsAt = widget.event?.startsAt ?? _nextHour();
  late DateTime? _endsAt = widget.event != null ? widget.event!.endsAt : _nextHour().add(const Duration(hours: 1));
  late bool _allDay = widget.event?.allDay ?? false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _location.dispose();
    super.dispose();
  }

  void _setKind(ItemKind kind) {
    setState(() {
      _kind = kind;
      // Inbox items always have a priority; there's no due date to work one out from.
      if (kind == ItemKind.inbox) _priority ??= Priority.medium;
    });
  }

  String? _iso(DateTime? time) => time?.toUtc().toIso8601String();

  Future<void> _save() async {
    final title = _title.text.trim();
    final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give it a name.');
      return;
    }
    if (_kind == ItemKind.event && !_allDay && _endsAt != null && !_endsAt!.isAfter(_startsAt)) {
      setState(() => _error = 'The end time has to be after the start.');
      return;
    }

    final (table, id, fields) = switch (_kind) {
      ItemKind.todo => (
          'tasks',
          widget.task?.id,
          {'title': title, 'notes': notes, 'due_at': _iso(_dueAt), 'priority': _priority?.dbValue},
        ),
      ItemKind.event => (
          'events',
          widget.event?.id,
          {
            'title': title,
            'notes': notes,
            'location': _location.text.trim().isEmpty ? null : _location.text.trim(),
            'all_day': _allDay,
            'starts_at': _iso(_allDay ? DateTime(_startsAt.year, _startsAt.month, _startsAt.day) : _startsAt),
            'ends_at': _allDay ? null : _iso(_endsAt),
            'priority': _priority?.dbValue,
          },
        ),
      ItemKind.inbox => (
          'inbox_items',
          widget.inboxItem?.id,
          {'title': title, 'summary': notes, 'deadline': _iso(_dueAt), 'priority': (_priority ?? Priority.medium).dbValue},
        ),
    };

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (id == null) {
        await supabase.from(table).insert(fields);
      } else {
        await updateRow(table, id, fields);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() {
        _saving = false;
        _error = "Couldn't save. Check your connection and try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.isEditing ? 'Edit ${_kind == ItemKind.todo ? 'task' : _kind.label.toLowerCase()}' : 'Create new item'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.isEditing) ...[
                SegmentedButton<ItemKind>(
                  segments: [
                    for (final kind in ItemKind.values)
                      ButtonSegment(value: kind, icon: Icon(kind.icon), label: Text(kind.label)),
                  ],
                  selected: {_kind},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) => _setKind(selection.first),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _title,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: switch (_kind) {
                    ItemKind.todo => 'What needs doing?',
                    ItemKind.event => 'Event name',
                    ItemKind.inbox => "What's it about?",
                  },
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              ..._kindFields(),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
                minLines: 1,
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              Text('Priority', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              PriorityPicker(
                value: _priority,
                allowAutomatic: _kind != ItemKind.inbox,
                onChanged: (p) => setState(() => _priority = p),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: Text(widget.isEditing ? 'Save' : 'Create')),
      ],
    );
  }

  List<Widget> _kindFields() => switch (_kind) {
        ItemKind.todo => [
            _DateField(
              label: 'Due',
              emptyLabel: 'Add due date',
              value: _dueAt,
              onChanged: (v) => setState(() => _dueAt = v),
            ),
          ],
        ItemKind.inbox => [
            _DateField(
              label: 'Deadline',
              emptyLabel: 'Add deadline',
              value: _dueAt,
              onChanged: (v) => setState(() => _dueAt = v),
            ),
          ],
        ItemKind.event => [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('All day'),
              value: _allDay,
              onChanged: (v) => setState(() => _allDay = v),
            ),
            _DateField(
              label: 'Starts',
              value: _startsAt,
              dateOnly: _allDay,
              onChanged: (v) => setState(() => _startsAt = v ?? _startsAt),
              clearable: false,
            ),
            if (!_allDay) ...[
              const SizedBox(height: 8),
              _DateField(
                label: 'Ends',
                emptyLabel: 'Add end time',
                value: _endsAt,
                onChanged: (v) => setState(() => _endsAt = v),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Location (optional)', prefixIcon: Icon(Icons.place_outlined)),
            ),
          ],
      };
}

/// A labeled chip that opens date (and time) pickers.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.emptyLabel = 'Pick a date',
    this.dateOnly = false,
    this.clearable = true,
  });

  final String label;
  final String emptyLabel;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool dateOnly;
  final bool clearable;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final initial = value ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !context.mounted) return;
    if (dateOnly) {
      onChanged(DateTime(date.year, date.month, date.day));
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: value != null ? TimeOfDay.fromDateTime(value!) : const TimeOfDay(hour: 23, minute: 59),
    );
    final t = time ?? (value != null ? TimeOfDay.fromDateTime(value!) : const TimeOfDay(hour: 23, minute: 59));
    onChanged(DateTime(date.year, date.month, date.day, t.hour, t.minute));
  }

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? emptyLabel
        : dateOnly
            ? DateFormat.yMMMEd().format(value!)
            : DateFormat.yMMMEd().add_jm().format(value!);
    return Row(
      children: [
        SizedBox(width: 72, child: Text(label, style: Theme.of(context).textTheme.labelLarge)),
        ActionChip(
          avatar: const Icon(Icons.event, size: 18),
          label: Text(text),
          onPressed: () => _pick(context),
        ),
        if (clearable && value != null)
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => onChanged(null),
          ),
      ],
    );
  }
}

/// Automatic / High / Medium / Low.
class PriorityPicker extends StatelessWidget {
  const PriorityPicker({super.key, required this.value, required this.onChanged, this.allowAutomatic = true});

  final Priority? value;
  final ValueChanged<Priority?> onChanged;
  final bool allowAutomatic;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (allowAutomatic)
          ChoiceChip(
            label: const Text('Automatic'),
            tooltip: 'Based on when it\'s due',
            selected: value == null,
            onSelected: (_) => onChanged(null),
          ),
        for (final p in Priority.values)
          ChoiceChip(
            avatar: CircleAvatar(backgroundColor: p.color, radius: 5),
            label: Text(p.label),
            selected: value == p,
            onSelected: (_) => onChanged(p),
          ),
      ],
    );
  }
}
