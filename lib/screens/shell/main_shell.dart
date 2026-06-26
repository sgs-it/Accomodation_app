// lib/screens/shell/main_shell.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static int _locationIndex(String location) {
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/rooms')) return 1;
    if (location.startsWith('/staff')) return 2;
    if (location.startsWith('/leave')) return 3;
    if (location.startsWith('/shifts')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final idx = _locationIndex(location);

    // Don't show nav bar in nested screens
    final showNav = location == '/dashboard' ||
        location == '/staff' ||
        location == '/leave' ||
        location == '/shifts';

    return Scaffold(
      body: child,
      bottomNavigationBar: showNav
          ? Container(
              decoration: const BoxDecoration(
                color: AppTheme.bgCard,
                border: Border(top: BorderSide(color: AppTheme.divider)),
              ),
              child: BottomNavigationBar(
                currentIndex: idx,
                onTap: (i) {
                  switch (i) {
                    case 0:
                      context.go('/dashboard');
                      break;
                    case 1:
                      // No direct rooms tab, go to dashboard
                      context.go('/dashboard');
                      break;
                    case 2:
                      context.go('/staff');
                      break;
                    case 3:
                      context.go('/leave');
                      break;
                    case 4:
                      context.go('/shifts');
                      break;
                  }
                },
                items: [
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.dashboard_rounded),
                    label: 'Dashboard',
                    activeIcon: const Icon(Icons.dashboard_rounded),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.meeting_room_outlined),
                    label: 'Rooms',
                    activeIcon: const Icon(Icons.meeting_room_rounded),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.people_outline),
                    label: 'Staff',
                    activeIcon: const Icon(Icons.people_rounded),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.flight_takeoff_outlined),
                    label: 'Leave',
                    activeIcon: const Icon(Icons.flight_takeoff_rounded),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.swap_horiz_outlined),
                    label: 'Shifts',
                    activeIcon: const Icon(Icons.swap_horiz_rounded),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
