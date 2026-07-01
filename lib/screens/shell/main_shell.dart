// lib/screens/shell/main_shell.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
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

    return Scaffold(
      extendBody: true, // Allows body to scroll behind the floating nav
      backgroundColor: Colors.transparent, // Background handled by child
      body: child,
      bottomNavigationBar: showNav
          ? SafeArea(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _NavItem(
                      icon: Icons.home_rounded,
                      label: 'Dashboard',
                      isSelected: idx == 0,
                      onTap: () => context.go('/dashboard'),
                    ),
                    _NavItem(
                      icon: Icons.people_outline_rounded,
                      label: 'Staff',
                      isSelected: idx == 1,
                      onTap: () => context.go('/staff'),
                    ),
                    _NavItem(
                      icon: Icons.calendar_today_outlined,
                      label: 'Leave',
                      isSelected: idx == 2,
                      onTap: () => context.go('/leave'),
                    ),
                    _NavItem(
                      icon: Icons.access_time_rounded,
                      label: 'Shifts',
                      isSelected: idx == 3,
                      onTap: () => context.go('/shifts'),
                    ),
                    if (isAdmin)
                      _NavItem(
                        icon: Icons.receipt_long_outlined,
                        label: 'Requests',
                        isSelected: idx == 4,
                        onTap: () => context.go('/requests'),
                        badgeCount: provider.pendingCount,
                      ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int badgeCount;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: const Color(0xFF8B5CF6), // Purple accent
                borderRadius: BorderRadius.circular(20),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                  size: 24,
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppTheme.danger,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isSelected ? Colors.white : const Color(0xFF64748B),
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
