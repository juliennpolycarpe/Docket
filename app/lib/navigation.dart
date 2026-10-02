import 'package:flutter/material.dart';

enum Destination {
  home('Home', Icons.home_outlined, Icons.home),
  upcoming('Upcoming', Icons.event_outlined, Icons.event),
  todo('To Do', Icons.check_circle_outline, Icons.check_circle),
  inbox('Inbox', Icons.inbox_outlined, Icons.inbox),
  customize('Customize', Icons.tune_outlined, Icons.tune),
  settings('Settings', Icons.settings_outlined, Icons.settings);

  const Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// The pages listed in the sidebar under "New".
  static const sidebar = [upcoming, todo, inbox, customize];
}
