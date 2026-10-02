import 'package:flutter/material.dart';

import '../api.dart';
import '../data.dart';
import '../widgets/item_cards.dart';
import '../widgets/item_editor.dart';
import '../widgets/priority_board.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  bool _showCompleted = false;
  bool _syncing = false;

  Future<void> _sync() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _syncing = true);
    try {
      final errors = await DocketApi.syncNow();
      if (errors.isNotEmpty) messenger.showSnackBar(SnackBar(content: Text('Some accounts failed to sync: ${errors.join('; ')}')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = DataScope.of(context);
    final now = DateTime.now();
    final open = data.tasks.where((t) => !t.isDone).length;
    final tasks = data.tasks.where((t) => _showCompleted || !t.isDone).toList()
      ..sort((a, b) {
        if (a.dueAt == null || b.dueAt == null) return (a.dueAt == null ? 1 : 0) - (b.dueAt == null ? 1 : 0);
        return a.dueAt!.compareTo(b.dueAt!);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'To Do',
          subtitle: '$open open · Canvas assignments and your own tasks',
          actions: [
            FilterChip(
              label: const Text('Show completed'),
              selected: _showCompleted,
              onSelected: (v) => setState(() => _showCompleted = v),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Sync now',
              onPressed: _syncing ? null : _sync,
              icon: _syncing
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => showNewItemEditor(context, kind: ItemKind.todo),
              icon: const Icon(Icons.add),
              label: const Text('Add task'),
            ),
          ],
        ),
        Expanded(
          child: data.isLoading
              ? const Center(child: CircularProgressIndicator())
              : PriorityBoard(
                  items: tasks,
                  priorityOf: (t) => t.effectivePriority(now),
                  cardBuilder: (t) => TaskCard(task: t, now: now),
                ),
        ),
      ],
    );
  }
}
