import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:staff_accommodation_app/providers/app_provider.dart';
import 'package:staff_accommodation_app/screens/shifts/shift_history_screen.dart';
import 'package:staff_accommodation_app/services/auth_service.dart';
import 'package:staff_accommodation_app/services/shift_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _TestAuthStorage extends GotrueAsyncStorage {
  @override
  Future<String?> getItem({required String key}) async => null;
  @override
  Future<void> removeItem({required String key}) async {}
  @override
  Future<void> setItem({required String key, required String value}) async {}
}

class _RoleProvider extends AppProvider {
  _RoleProvider(this.testRole);

  final UserRole testRole;

  @override
  UserRole get role => testRole;
  @override
  bool get isAdmin => testRole == UserRole.admin;
  @override
  bool get isStaff => testRole == UserRole.staff;
  @override
  bool get isSupervisor => testRole == UserRole.supervisor;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  var failRequest = false;
  final rows = [
    {
      'id': 'shift-1',
      'staff_id': 'staff-1',
      'shift_date': '2026-07-01',
      'staff': {'name': 'Earlier Staff', 'staff_id': 'S1'},
    },
    {
      'id': 'shift-2',
      'staff_id': 'staff-2',
      'shift_date': '2026-07-02',
      'staff': {'name': 'Later Staff', 'staff_id': 'S2'},
    },
  ];

  setUpAll(() async {
    // Supply font assets in memory so widget tests never fetch Google Fonts.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (key == 'AssetManifest.bin') {
            return const StandardMessageCodec().encodeMessage({
              for (final weight in ['Regular', 'SemiBold', 'Bold'])
                'fonts/Inter-$weight.ttf': [
                  {'asset': 'fonts/Inter-$weight.ttf'},
                ],
            });
          }
          if (key.endsWith('.ttf')) return ByteData(0);
          return null;
        });
    await Supabase.initialize(
      url: 'https://shift-tests.supabase.co',
      publishableKey: 'test-key',
      debug: false,
      authOptions: FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: _TestAuthStorage(),
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (failRequest) {
          return http.Response(
            '{"message":"Unavailable"}',
            400,
            request: request,
          );
        }
        var result = rows.toList();
        for (final filter
            in request.url.queryParametersAll['shift_date'] ?? []) {
          final date = filter.substring(4);
          result = result.where((row) {
            final comparison = (row['shift_date'] as String).compareTo(date);
            return filter.startsWith('gte.')
                ? comparison >= 0
                : comparison <= 0;
          }).toList();
        }
        final ascending = request.url.queryParameters['order']!.contains(
          '.asc',
        );
        result.sort((a, b) {
          final comparison = (a['shift_date'] as String).compareTo(
            b['shift_date'] as String,
          );
          return ascending ? comparison : -comparison;
        });
        return http.Response(
          jsonEncode(result),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
  });

  tearDownAll(() async => Supabase.instance.dispose());

  setUp(() {
    requests.clear();
    failRequest = false;
  });

  Future<void> openScreen(WidgetTester tester, UserRole role) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>(
        create: (_) => _RoleProvider(role),
        child: const MaterialApp(home: ShiftHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> setDate(
    WidgetTester tester,
    String prefix,
    DateTime date,
  ) async {
    for (final part in {
      'year': date.year,
      'month': date.month,
      'day': date.day,
    }.entries) {
      tester
          .widget<DropdownButton<int>>(
            find.byKey(ValueKey('shift-$prefix-${part.key}')),
          )
          .onChanged!(part.value);
      await tester.pumpAndSettle();
    }
  }

  Future<void> selectRange(WidgetTester tester, DateTimeRange range) async {
    await tester.tap(find.widgetWithText(OutlinedButton, 'Filter by date'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(DateRangePickerDialog), findsNothing);
    await setDate(tester, 'start', range.start);
    await setDate(tester, 'end', range.end);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
  }

  test(
    'default service call keeps all history and newest-first ordering',
    () async {
      final shifts = await ShiftService().getAll();
      expect(shifts.map((shift) => shift.id), ['shift-2', 'shift-1']);
      expect(requests.single.url.queryParametersAll['shift_date'], isNull);
      expect(
        requests.single.url.queryParameters['order'],
        startsWith('shift_date.desc'),
      );
    },
  );

  test(
    'service includes both boundary dates and preserves staff filtering',
    () async {
      await ShiftService().getAll(
        staffId: 'staff-1',
        startDate: DateTime(2026, 7, 1, 12),
        endDate: DateTime(2026, 7, 2, 23, 59),
        ascending: true,
      );
      expect(requests.single.url.queryParametersAll['shift_date'], [
        'gte.2026-07-01',
        'lte.2026-07-02',
      ]);
      expect(requests.single.url.queryParameters['staff_id'], 'eq.staff-1');
      expect(
        requests.single.url.queryParameters['order'],
        startsWith('shift_date.asc'),
      );
    },
  );

  for (final role in [UserRole.staff, UserRole.supervisor]) {
    testWidgets('$role has no filter or sorting controls', (tester) async {
      await openScreen(tester, role);
      expect(find.text('Filter by date'), findsNothing);
      expect(find.byType(PopupMenuButton<bool>), findsNothing);
      expect(find.text('Shift History'), findsOneWidget);
      expect(find.text('My Requests'), findsOneWidget);
      expect(requests.single.url.queryParametersAll['shift_date'], isNull);
    });
  }

  testWidgets('admin can filter a single day, refresh, sort and clear', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openScreen(tester, UserRole.admin);
    expect(find.text('Earlier Staff'), findsOneWidget);
    expect(find.text('Later Staff'), findsOneWidget);

    await selectRange(
      tester,
      DateTimeRange(start: DateTime(2026, 7, 2), end: DateTime(2026, 7, 2)),
    );
    expect(find.text('Earlier Staff'), findsNothing);
    expect(find.text('Later Staff'), findsOneWidget);
    expect(requests.last.url.queryParametersAll['shift_date'], [
      'gte.2026-07-02',
      'lte.2026-07-02',
    ]);

    final refresh = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    await refresh.onRefresh();
    await tester.pumpAndSettle();
    expect(requests.last.url.queryParametersAll['shift_date'], [
      'gte.2026-07-02',
      'lte.2026-07-02',
    ]);

    await tester.tap(find.byType(PopupMenuButton<bool>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oldest first'));
    await tester.pumpAndSettle();
    expect(
      requests.last.url.queryParameters['order'],
      startsWith('shift_date.asc'),
    );
    expect(requests.last.url.queryParametersAll['shift_date'], isNotNull);

    await tester.tap(find.text('Clear filter'));
    await tester.pumpAndSettle();
    expect(requests.last.url.queryParametersAll['shift_date'], isNull);
    expect(find.text('Earlier Staff'), findsOneWidget);
    expect(find.text('Later Staff'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Earlier Staff')).dy,
      lessThan(tester.getTopLeft(find.text('Later Staff')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty filtered range can be cleared', (tester) async {
    await openScreen(tester, UserRole.admin);
    await selectRange(
      tester,
      DateTimeRange(start: DateTime(2026, 6, 1), end: DateTime(2026, 6, 2)),
    );
    expect(find.text('No shifts in this date range'), findsOneWidget);
    await tester.tap(find.text('Clear filter'));
    await tester.pumpAndSettle();
    expect(find.text('Earlier Staff'), findsOneWidget);
    expect(find.text('Later Staff'), findsOneWidget);
  });

  testWidgets('cancelling picker keeps history unfiltered', (tester) async {
    await openScreen(tester, UserRole.admin);
    await tester.tap(find.text('Filter by date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(requests, hasLength(1));
    expect(find.text('Clear filter'), findsNothing);
    expect(find.text('Earlier Staff'), findsOneWidget);
  });

  testWidgets(
    'popup supports ranges across months and years and retains selection',
    (tester) async {
      await openScreen(tester, UserRole.admin);
      await selectRange(
        tester,
        DateTimeRange(start: DateTime(2025, 12, 15), end: DateTime(2026, 7, 2)),
      );
      expect(requests.last.url.queryParametersAll['shift_date'], [
        'gte.2025-12-15',
        'lte.2026-07-02',
      ]);
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButton<int>>(
              find.byKey(const ValueKey('shift-start-year')),
            )
            .value,
        2025,
      );
      expect(
        tester
            .widget<DropdownButton<int>>(
              find.byKey(const ValueKey('shift-start-month')),
            )
            .value,
        12,
      );
      final popup = tester.getRect(find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(Material),
      ).first);
      expect(
        popup.width,
        lessThan(tester.view.physicalSize.width / tester.view.devicePixelRatio),
      );
      expect(
        popup.height,
        lessThan(
          tester.view.physicalSize.height / tester.view.devicePixelRatio,
        ),
      );
    },
  );

  testWidgets(
    'month and year changes clamp leap dates and invalid ranges cannot apply',
    (tester) async {
      await openScreen(tester, UserRole.admin);
      await tester.tap(find.text('Filter by date'));
      await tester.pumpAndSettle();
      await setDate(tester, 'start', DateTime(2024, 2, 29));
      await tester.tap(find.byKey(const ValueKey('shift-start-year')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2025').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButton<int>>(
              find.byKey(const ValueKey('shift-start-day')),
            )
            .value,
        28,
      );
      await setDate(tester, 'end', DateTime(2025, 1, 1));
      expect(
        find.text('Start date must be on or before end date.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Apply'))
            .onPressed,
        isNull,
      );
      expect(requests, hasLength(1));
    },
  );

  testWidgets('failed query offers a retry instead of an empty result', (
    tester,
  ) async {
    failRequest = true;
    await openScreen(tester, UserRole.admin);
    expect(
      find.text('Could not load shift details. Please try again.'),
      findsOneWidget,
    );
    failRequest = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Earlier Staff'), findsOneWidget);
  });
}
