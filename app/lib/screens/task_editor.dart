import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/task.dart';

/// Opens the add/edit dialog for a task you created yourself.
Future<void> showTaskEditor(BuildContext context, {Task? task}) {
  return showDialog(context: context, builder: (_) => _TaskEditorDialog(task: task));
}

class _TaskEditorDialog extends StatefulWidget {
  const _TaskEditorDialog({this.task});

  final Task? task;

  @override
  State<_TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends State<_TaskEditorDialog> {
  late final _title = TextEditingController(text: widget.task?.title);
  late final _notes = TextEditingController(text: widget.task?.notes);
  late DateTime? _dueAt = widget.task?.dueAt;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _dueAt != null ? TimeOfDay.fromDateTime(_dueAt!) : const TimeOfDay(hour: 23, minute: 59),
    );
    final t = time ?? const TimeOfDay(hour: 23, minute: 59);
    setState(() => _dueAt = DateTime(date.year, date.month, date.day, t.hour, t.minute));
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give the task a name');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final fields = {
      'title': title,
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      'due_at': _dueAt?.toUtc().toIso8601String(),
    };
    try {
      final existing = widget.task;
      if (existing == null) {
        await supabase.from('tasks').insert(fields);
      } else {
        await supabase.from('tasks').update(fields).eq('id', existing.id);
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
      title: Text(widget.task == null ? 'New task' : 'Edit task'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'What needs doing?'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              minLines: 1,
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.event, size: 18),
                  label: Text(_dueAt == null ? 'Add due date' : DateFormat.yMMMd().add_jm().format(_dueAt!)),
                  onPressed: _pickDue,
                ),
                if (_dueAt != null)
                  IconButton(
                    tooltip: 'Remove due date',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _dueAt = null),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
