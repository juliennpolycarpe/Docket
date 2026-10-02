import 'package:flutter/material.dart';

import '../main.dart';
import '../navigation.dart';
import '../profile.dart';
import 'user_avatar.dart';

const sidebarWidth = 264.0;
const collapsedSidebarWidth = 64.0;

class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.collapsed,
    required this.selected,
    required this.onSelect,
    required this.onNew,
    required this.searchController,
    required this.searchFocus,
    required this.onSearchChanged,
    this.onToggleCollapsed,
  });

  final bool collapsed;
  final Destination? selected; // null while showing search results
  final ValueChanged<Destination> onSelect;
  final VoidCallback onNew;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onToggleCollapsed; // null = can't collapse (phone drawer)

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toggle = onToggleCollapsed == null
        ? null
        : IconButton(
            tooltip: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
            icon: const Icon(Icons.view_sidebar_outlined, size: 20),
            onPressed: onToggleCollapsed,
          );

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo (goes home) and collapse button
          if (collapsed)
            Center(child: toggle)
          else
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onSelect(Destination.home),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.checklist_rounded, color: theme.colorScheme.primary),
                          const SizedBox(width: 10),
                          Text('Docket', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
                ?toggle,
              ],
            ),
          const SizedBox(height: 8),

          // Search
          if (collapsed)
            _NavItem(
              icon: Icons.search,
              label: 'Search',
              collapsed: true,
              onTap: () {
                onToggleCollapsed?.call();
                // The search field only exists once the sidebar has expanded.
                WidgetsBinding.instance.addPostFrameCallback((_) => searchFocus.requestFocus());
              },
            )
          else
            TextField(
              controller: searchController,
              focusNode: searchFocus,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search',
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          searchController.clear();
                          onSearchChanged('');
                        },
                      ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          const SizedBox(height: 8),

          _NavItem(icon: Icons.add, label: 'New', collapsed: collapsed, onTap: onNew),
          const SizedBox(height: 4),
          for (final destination in Destination.sidebar)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: _NavItem(
                icon: selected == destination ? destination.selectedIcon : destination.icon,
                label: destination.label,
                collapsed: collapsed,
                selected: selected == destination,
                onTap: () => onSelect(destination),
              ),
            ),
          const Spacer(),
          _ProfileButton(collapsed: collapsed, onSettings: () => onSelect(Destination.settings)),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.collapsed,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final bool collapsed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final item = Material(
      color: selected ? scheme.surfaceContainerHighest : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 10, vertical: 9),
          child: Row(
            mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: selected ? scheme.onSurface : scheme.onSurfaceVariant),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return collapsed ? Tooltip(message: label, child: item) : item;
  }
}

/// Avatar and name at the bottom. Click for Settings and Log out.
class _ProfileButton extends StatelessWidget {
  const _ProfileButton({required this.collapsed, required this.onSettings});

  final bool collapsed;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = supabase.auth.currentUser;
    return MenuAnchor(
      style: const MenuStyle(minimumSize: WidgetStatePropertyAll(Size(220, 0))),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Text(user?.email ?? '', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
        const Divider(height: 1),
        MenuItemButton(leadingIcon: const Icon(Icons.settings_outlined), onPressed: onSettings, child: const Text('Settings')),
        MenuItemButton(
          leadingIcon: const Icon(Icons.logout),
          onPressed: () => supabase.auth.signOut(),
          child: const Text('Log out'),
        ),
      ],
      builder: (context, controller, _) {
        void toggle() => controller.isOpen ? controller.close() : controller.open();
        final avatar = UserAvatar(user: user);
        if (collapsed) {
          return Tooltip(
            message: fullName(user) ?? user?.email ?? 'Profile',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: toggle,
              child: Padding(padding: const EdgeInsets.all(8), child: avatar),
            ),
          );
        }
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: toggle,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                avatar,
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fullName(user) ?? 'Add your name', overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                      Text(
                        user?.email ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.unfold_more, size: 18, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        );
      },
    );
  }
}
