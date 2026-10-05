import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data.dart';
import '../main.dart';
import '../navigation.dart';
import '../widgets/item_editor.dart';
import '../widgets/sidebar.dart';
import 'coming_soon_screen.dart';
import 'events_screen.dart';
import 'home_screen.dart';
import 'inbox_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'todo_screen.dart';

/// Sidebar plus the current page. On phones the sidebar becomes a drawer.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _data = DocketData();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  late final StreamSubscription<AuthState> _authChanges;
  Destination _destination = Destination.home;
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    // Name and profile picture changes come through here.
    _authChanges = supabase.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _authChanges.cancel();
    _data.dispose();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  bool get _searching => _search.text.trim().isNotEmpty;

  void _select(Destination destination) {
    setState(() {
      _destination = destination;
      _search.clear();
    });
    _scaffoldKey.currentState?.closeDrawer();
  }

  void _newItem() {
    _scaffoldKey.currentState?.closeDrawer();
    showNewItemEditor(context, kind: switch (_destination) {
      Destination.upcoming => ItemKind.event,
      Destination.inbox => ItemKind.inbox,
      _ => ItemKind.todo,
    });
  }

  Widget _page() {
    if (_searching) return SearchScreen(query: _search.text.trim());
    return switch (_destination) {
      Destination.home => HomeScreen(onOpen: _select),
      Destination.upcoming => const EventsScreen(),
      Destination.todo => const TodoScreen(),
      Destination.inbox => const InboxScreen(),
      Destination.customize => const ComingSoonScreen(
          icon: Icons.tune,
          message: 'Choose what shows up on your home page, colors, and more.',
        ),
      Destination.settings => const SettingsScreen(),
    };
  }

  Sidebar _sidebar({required bool collapsed, required bool canCollapse}) => Sidebar(
        collapsed: collapsed,
        selected: _searching ? null : _destination,
        onSelect: _select,
        onNew: _newItem,
        searchController: _search,
        searchFocus: _searchFocus,
        onSearchChanged: (_) => setState(() {}),
        onToggleCollapsed: canCollapse ? () => setState(() => _collapsed = !_collapsed) : null,
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 800;

    final Widget scaffold;
    if (wide) {
      final width = _collapsed ? collapsedSidebarWidth : sidebarWidth;
      scaffold = Scaffold(
        key: _scaffoldKey,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The sidebar is laid out at its final width and clipped while the
            // width animates, so its contents never get squeezed mid-animation.
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: width,
              // A Material (not a plain color) so hover highlights inside the sidebar show up.
              child: Material(
                color: scheme.surfaceContainerLow,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    minWidth: width,
                    maxWidth: width,
                    child: _sidebar(collapsed: _collapsed, canCollapse: true),
                  ),
                ),
              ),
            ),
            VerticalDivider(width: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
            Expanded(child: _page()),
          ],
        ),
      );
    } else {
      scaffold = Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(title: Text(_searching ? 'Search' : _destination.label)),
        drawer: Drawer(
          width: sidebarWidth + 16,
          backgroundColor: scheme.surfaceContainerLow,
          child: SafeArea(child: _sidebar(collapsed: false, canCollapse: false)),
        ),
        body: _page(),
      );
    }
    return DataScope(data: _data, child: scaffold);
  }
}
