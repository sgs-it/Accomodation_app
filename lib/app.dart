// lib/app.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme.dart';
import 'providers/app_provider.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/rooms/rooms_list_screen.dart';
import 'screens/rooms/room_detail_screen.dart';
import 'screens/staff/staff_list_screen.dart';
import 'screens/staff/staff_detail_screen.dart';
import 'screens/leave/leave_screen.dart';
import 'screens/shifts/shift_history_screen.dart';
import 'screens/users/users_screen.dart';
import 'screens/requests/pending_requests_screen.dart';
import 'screens/shell/main_shell.dart';
import 'screens/beds/beds_filter_screen.dart';
import 'screens/staff/unassigned_staff_screen.dart';
import 'screens/staff/on_leave_staff_screen.dart';

final _router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final path = state.uri.path;
    final loggedIn = session != null;
    if (!loggedIn && path != '/' && path != '/login') return '/login';
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (ctx, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (ctx, state) => const LoginScreen()),
    ShellRoute(
      builder: (ctx, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (ctx, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/rooms/:locationId',
          builder: (ctx, state) => RoomsListScreen(
            locationId: state.pathParameters['locationId']!,
          ),
          routes: [
            GoRoute(
              path: ':roomId',
              builder: (ctx, state) => RoomDetailScreen(
                locationId: state.pathParameters['locationId']!,
                roomId: state.pathParameters['roomId']!,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/staff',
          builder: (ctx, state) => const StaffListScreen(),
          routes: [
            GoRoute(
              path: ':staffId',
              builder: (ctx, state) => StaffDetailScreen(
                staffId: state.pathParameters['staffId']!,
              ),
            ),
          ],
        ),
        GoRoute(path: '/leave', builder: (ctx, state) => const LeaveScreen()),
        GoRoute(
            path: '/shifts',
            builder: (ctx, state) => const ShiftHistoryScreen()),
        GoRoute(
            path: '/unassigned',
            builder: (ctx, state) => const UnassignedStaffScreen()),
        GoRoute(
            path: '/on-leave',
            builder: (ctx, state) => const OnLeaveStaffScreen()),
        GoRoute(
            path: '/users',
            builder: (ctx, state) => const UsersScreen()),
        GoRoute(
            path: '/requests',
            builder: (ctx, state) => const PendingRequestsScreen()),
        GoRoute(
            path: '/beds-overview/:filter',
            builder: (ctx, state) => BedsFilterScreen(
                  filter: state.pathParameters['filter']!,
                )),
      ],
    ),
  ],
);

class StaffAccommApp extends StatelessWidget {
  const StaffAccommApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: MaterialApp.router(
        title: 'Staff Accommodation',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        routerConfig: _router,
      ),
    );
  }
}
