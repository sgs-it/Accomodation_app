// lib/screens/shell/main_shell.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static int _locationIndex(String location, bool isAdmin) {
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/staff'))     return 1;
    if (location.startsWith('/leave'))     return 2;
    if (location.startsWith('/shifts'))    return 3;
    if (location.startsWith('/requests'))  return isAdmin ? 4 : -1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final provider  = context.watch<AppProvider>();
    final isAdmin   = provider.isAdmin;
    final idx       = _locationIndex(location, isAdmin);

    // Only show nav on top-level screens
    final showNav = location == '/dashboard' ||
        location == '/staff' ||
        location == '/leave' ||
        location == '/shifts' ||
        location == '/requests';

    // Nav items differ by role
    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.dashboard_rounded),
        label: 'Dashboard',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.people_outline),
        activeIcon: Icon(Icons.people_rounded),
        label: 'Staff',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.flight_takeoff_outlined),
        activeIcon: Icon(Icons.flight_takeoff_rounded),
        label: 'Leave',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.swap_horiz_outlined),
        activeIcon: Icon(Icons.swap_horiz_rounded),
        label: 'Shifts',
      ),
      if (isAdmin)
        BottomNavigationBarItem(
          icon: _RequestsBadge(count: provider.pendingCount),
          activeIcon: _RequestsBadge(
              count: provider.pendingCount, active: true),
          label: 'Requests',
        ),
    ];

    return Scaffold(
      body: child,
      bottomNavigationBar: showNav
          ? Container(
              decoration: const BoxDecoration(
                color: AppTheme.bgCard,
                border: Border(top: BorderSide(color: AppTheme.divider)),
              ),
              child: BottomNavigationBar(
                currentIndex: idx < 0 ? 0 : idx,
                onTap: (i) {
                  switch (i) {
                    case 0: context.go('/dashboard'); break;
                    case 1: context.go('/staff');     break;
                    case 2: context.go('/leave');     break;
                    case 3: context.go('/shifts');    break;
                    case 4:
                      if (isAdmin) context.go('/requests');
                      break;
                  }
                },
                items: items,
              ),
            )
          : null,
    );
  }
}

class _RequestsBadge extends StatelessWidget {
  final int count;
  final bool active;
  const _RequestsBadge({required this.count, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          active
              ? Icons.pending_actions_rounded
              : Icons.pending_actions_outlined,
        ),
        if (count > 0)
          Positioned(
            right: -8,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: AppTheme.danger,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
