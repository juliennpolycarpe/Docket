import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../main.dart';
import '../models/task.dart';
import 'task_editor.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  // Live: updates when the server syncs Canvas or another device changes something.
  final Stream<List<Task>> _tasks =
      supabase.from('tasks').stream(primaryKey: ['id']).map((rows) => rows.map(Task.fromRow).toList());
  bool _showDone = false;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sync() async {
    try {
      final errors = await DocketApi.syncNow();
      if (errors.isNotEmpty) _showMessage('Some accounts failed to sync: ${errors.join('; ')}');
    } on ApiException catch (e) {
      _showMessage(e.message);
    }
  }

  Future<void> _setCompleted(Task task, bool completed) async {
    try {
      await supabase.from('tasks').update({'completed': completed}).eq('id', task.id);
    } catch (_) {
      _showMessage("Couldn't update that task. Try again.");
    }
  }

  Future<void> _delete(Task task) async {
    try {
      await supabase.from('tasks').delete().eq('id', task.id);
    } catch (_) {
      _showMessage("Couldn't delete that task. Try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTaskEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Add task'),
      ),
      body: StreamBuilder<List<Task>>(
        stream: _tasks,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Couldn't load your tasks. Check your connection."));
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          return RefreshIndicator(onRefresh: _sync, child: _buildList(snapshot.data!));
        },
      ),
    );
  }

  Widget _buildList(List<Task> tasks) {
    final theme = Theme.of(context);
    if (tasks.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(32),
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text('Nothing to do yet', textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Add a task, or connect Canvas with the link button at the top to bring in your assignments.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      );
    }

    final now = DateTime.now();
    final groups = groupTasks(tasks, now);
    final done = groups[TaskSection.done]!;
    return ListView(
      padding: const EdgeInsets.only(bottom: 96), // room for the Add button
      children: [
        for (final section in TaskSection.values)
          if (section != TaskSection.done && groups[section]!.isNotEmpty) ...[
            _SectionHeader(
              label: section.label,
              count: groups[section]!.length,
              color: section == TaskSection.overdue ? theme.colorScheme.error : null,
            ),
            for (final task in groups[section]!) _taskTile(task, now),
          ],
        if (done.isNotEmpty) ...[
          InkWell(
            onTap: () => setState(() => _showDone = !_showDone),
            child: Row(
              children: [
                Expanded(child: _SectionHeader(label: TaskSection.done.label, count: done.length)),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Icon(_showDone ? Icons.expand_less : Icons.expand_more),
                ),
              ],
            ),
          ),
          if (_showDone) for (final task in done) _taskTile(task, now),
        ],
      ],
    );
  }

  Widget _taskTile(Task task, DateTime now) {
    final theme = Theme.of(context);
    final overdue = !task.isDone && task.dueAt != null && task.dueAt!.isBefore(now);
    final details = [
      if (task.courseName != null) task.courseName!,
      if (task.dueAt != null) formatDue(task.dueAt!, now),
      if (task.submitted) 'Submitted in Canvas',
    ];

    return ListTile(
      leading: Tooltip(
        message: task.submitted ? 'Submitted in Canvas' : '',
        child: Checkbox(
          value: task.isDone,
          onChanged: task.submitted ? null : (value) => _setCompleted(task, value ?? false),
        ),
      ),
      title: Text(
        task.title,
        style: task.isDone
            ? TextStyle(decoration: TextDecoration.lineThrough, color: theme.colorScheme.onSurfaceVariant)
            : null,
      ),
      subtitle: details.isEmpty
          ? null
          : Text(details.join(' · '), style: overdue ? TextStyle(color: theme.colorScheme.error) : null),
      onTap: task.isManual ? () => showTaskEditor(context, task: task) : null,
      trailing: task.isManual
          ? PopupMenuButton<String>(
              onSelected: (value) => value == 'delete' ? _delete(task) : showTaskEditor(context, task: task),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            )
          : task.url == null
              ? null
              : IconButton(
                  tooltip: 'Open in Canvas',
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => launchUrl(Uri.parse(task.url!)),
                ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count, this.color});

  final String label;
  final int count;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        '$label  ($count)',
        style: theme.textTheme.titleSmall?.copyWith(color: color ?? theme.colorScheme.primary),
      ),
    );
  }
}

/// "Today, 11:59 PM", "Tomorrow, 9:00 AM", "Friday, 5:00 PM", "Oct 14, 11:59 PM"
String formatDue(DateTime due, DateTime now) {
  final days = DateTime.utc(due.year, due.month, due.day).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  final time = DateFormat.jm().format(due);
  if (days == 0) return 'Today, $time';
  if (days == 1) return 'Tomorrow, $time';
  if (days == -1) return 'Yesterday, $time';
  if (days > 1 && days < 7) return '${DateFormat.EEEE().format(due)}, $time';
  final date = due.year == now.year ? DateFormat.MMMd().format(due) : DateFormat.yMMMd().format(due);
  return '$date, $time';
}
