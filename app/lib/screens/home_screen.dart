import 'package:flutter/material.dart';

import '../main.dart';
import 'accounts_screen.dart';
import 'coming_soon_screen.dart';
import 'todo_screen.dart';

class _Tab {
  const _Tab(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _tabs = [
  _Tab('Upcoming Events', Icons.event_outlined, Icons.event),
  _Tab('To Do', Icons.check_circle_outline, Icons.check_circle),
  _Tab('Inbox', Icons.mail_outline, Icons.mail),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 1; // To Do is the only tab with data so far

  Widget _body() => switch (_index) {
        0 => const ComingSoonScreen(
            icon: Icons.event,
            message: 'Events from Outlook and Google Calendar will show up here.',
          ),
        1 => const TodoScreen(),
        _ => const ComingSoonScreen(
            icon: Icons.mail,
            message: 'Your Gmail and Outlook emails, summarized and sorted by priority, will show up here.',
          ),
      };

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final appBar = AppBar(
      title: Text(_tabs[_index].label),
      actions: [
        IconButton(
          tooltip: 'Connected accounts',
          icon: const Icon(Icons.link),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountsScreen())),
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'sign-out') supabase.auth.signOut();
          },
          itemBuilder: (context) => [
            PopupMenuItem(enabled: false, child: Text(supabase.auth.currentUser?.email ?? '')),
            const PopupMenuItem(value: 'sign-out', child: Text('Log out')),
          ],
        ),
      ],
    );

    if (wide) {
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final tab in _tabs)
                  NavigationRailDestination(icon: Icon(tab.icon), selectedIcon: Icon(tab.selectedIcon), label: Text(tab.label)),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _body()),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: _body(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final tab in _tabs) NavigationDestination(icon: Icon(tab.icon), selectedIcon: Icon(tab.selectedIcon), label: tab.label),
        ],
      ),
    );
  }
}
