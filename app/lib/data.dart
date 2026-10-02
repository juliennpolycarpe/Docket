import 'dart:async';

import 'package:flutter/material.dart';

import 'main.dart';
import 'models/event.dart';
import 'models/inbox_item.dart';
import 'models/task.dart';

/// Live copies of the signed-in user's tasks, events and inbox items. Supabase
/// pushes changes (from the server's syncs or another device) as they happen.
class DocketData extends ChangeNotifier {
  DocketData() {
    _subscriptions = [
      _listen('tasks', Task.fromRow, (rows) => tasks = rows),
      _listen('events', Event.fromRow, (rows) => events = rows),
      _listen('inbox_items', InboxItem.fromRow, (rows) => inbox = rows),
    ];
  }

  late final List<StreamSubscription<void>> _subscriptions;
  List<Task> tasks = [];
  List<Event> events = [];
  List<InboxItem> inbox = [];
  final Set<String> _loaded = {};
  Object? error;

  bool get isLoading => _loaded.length < 3 && error == null;

  StreamSubscription<void> _listen<T>(
    String table,
    T Function(Map<String, dynamic>) parse,
    void Function(List<T>) store,
  ) {
    return supabase.from(table).stream(primaryKey: ['id']).listen(
      (rows) {
        store(rows.map(parse).toList());
        _loaded.add(table);
        error = null;
        notifyListeners();
      },
      onError: (Object e) {
        error = e;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }
}

class DataScope extends InheritedNotifier<DocketData> {
  const DataScope({super.key, required DocketData data, required super.child}) : super(notifier: data);

  static DocketData of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<DataScope>()!.notifier!;
}

/// Runs a database write and shows a message if it fails. Returns whether it worked.
Future<bool> saveOrComplain(BuildContext context, Future<void> Function() write,
    {String failure = "Couldn't save that. Check your connection and try again."}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await write();
    return true;
  } catch (_) {
    messenger?.showSnackBar(SnackBar(content: Text(failure)));
    return false;
  }
}

Future<void> updateRow(String table, String id, Map<String, dynamic> fields) =>
    supabase.from(table).update(fields).eq('id', id);

Future<void> deleteRow(String table, String id) => supabase.from(table).delete().eq('id', id);
