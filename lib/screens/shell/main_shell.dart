// lib/screens/shell/main_shell.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';
import '../../services/auth_service.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {

  static int _locationIndex(String location, bool isAdmin) {
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/staff'))     return 1;
    if (location.startsWith('/leave'))     return 2;
    if (location.startsWith('/shifts'))    return 3;
    if (location.startsWith('/requests'))  return isAdmin ? 4 : -1;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AppProvider>();
      if (provider.role == UserRole.unknown) {
        provider.init().then((_) {
          if (provider.isAdmin) _checkReturns();
        });
      } else if (provider.isAdmin) {
        _checkReturns();
      }
    });
  }

  Future<void> _checkReturns() async {
    final client = Supabase.instance.client;
    try {
      // Find unassigned staff
      final staffData = await client
          .from('staff')
          .select('id, name, bed_assignments(id), pending_changes(id, change_type, status, payload, created_at)')
          .eq('status', 'On Leave')
          .order('created_at', ascending: false);

      for (final staff in staffData) {
        final assignments = staff['bed_assignments'] as List?;
        if (assignments == null || assignments.isEmpty) {
          final changes = staff['pending_changes'] as List?;
          if (changes != null) {
            final annualLeaves = changes
                .where((c) =>
                    c['change_type'] == 'leave_request' &&
                    c['status'] == 'approved' &&
                    c['payload']['leave_type'] == 'Annual leave')
                .toList();

            if (annualLeaves.isNotEmpty) {
              annualLeaves.sort((a, b) {
                final dateA = DateTime.parse(a['created_at']);
                final dateB = DateTime.parse(b['created_at']);
                return dateB.compareTo(dateA); // desc
              });
              
              final latest = annualLeaves.first;
              final returnDateStr = latest['payload']['to_date'] as String?;
              final returnNotified = latest['payload']['return_notified'] == true;

              if (returnDateStr != null && !returnNotified) {
                final returnDate = DateTime.tryParse(returnDateStr);
                if (returnDate != null) {
                  final diff = returnDate.difference(DateTime.now()).inDays;
                  if (diff <= 10 && diff >= 0) {
                    // Trigger notification
                    await client.functions.invoke(
                      'notify_admins',
                      body: {
                        'title': 'Staff Returning Soon',
                        'body': 'Reminder: Staff <b>${staff['name']}</b> is returning from Annual Leave in $diff days. Please assign them a new bed.'
                      },
                    );

                    // Mark as notified
                    final newPayload = Map<String, dynamic>.from(latest['payload']);
                    newPayload['return_notified'] = true;
                    await client.from('pending_changes').update({'payload': newPayload}).eq('id', latest['id']);
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error in 10-day return check: $e');
    }
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
      body: widget.child,
      bottomNavigationBar: showNav
          ? SafeArea(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                  size: 22,
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
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              softWrap: false,
              overflow: TextOverflow.visible,
            ),
          ],
        ),
      ),
    );
  }
}
