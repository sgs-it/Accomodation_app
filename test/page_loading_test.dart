import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:staff_accommodation_app/models/staff.dart';
import 'package:staff_accommodation_app/providers/app_provider.dart';
import 'package:staff_accommodation_app/screens/staff/staff_list_screen.dart';
import 'package:staff_accommodation_app/services/auth_service.dart';
import 'package:staff_accommodation_app/services/location_service.dart';
import 'package:staff_accommodation_app/services/pending_service.dart';
import 'package:staff_accommodation_app/services/staff_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _AuthStorage extends GotrueAsyncStorage {
  @override
  Future<String?> getItem({required String key}) async => null;
  @override
  Future<void> setItem({required String key, required String value}) async {}
  @override
  Future<void> removeItem({required String key}) async {}
}

class _AdminProvider extends AppProvider {
  @override
  UserRole get role => UserRole.admin;
  @override
  bool get isAdmin => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  Completer<void>? responseGate;
  var failLocations = false;
  var failAdmins = false;
  var staffName = 'Alice';

  http.Response response(
    http.Request request,
    Object body, {
    int status = 200,
  }) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
    request: request,
  );

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (key == 'AssetManifest.bin') {
            return const StandardMessageCodec().encodeMessage({
              for (final weight in [
                'Thin',
                'ExtraLight',
                'Light',
                'Regular',
                'Medium',
                'SemiBold',
                'Bold',
                'ExtraBold',
                'Black',
              ])
                'fonts/Inter-$weight.ttf': [
                  {'asset': 'fonts/Inter-$weight.ttf'},
                ],
            });
          }
          return key.endsWith('.ttf') ? ByteData(0) : null;
        });
    await Supabase.initialize(
      url: 'https://page-loading-tests.supabase.co',
      publishableKey: 'test-key',
      debug: false,
      authOptions: FlutterAuthClientOptions(
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: _AuthStorage(),
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (responseGate != null) await responseGate!.future;
        final table = request.url.pathSegments.last;
        final select = request.url.queryParameters['select'] ?? '';
        switch (table) {
          case 'locations':
            return failLocations
                ? response(request, {'message': 'Unavailable'}, status: 400)
                : response(request, [
                    {'id': 'loc-1', 'name': 'Main Location'},
                  ]);
          case 'beds':
            return response(request, [
              for (final status in ['FULL', 'VACATION', 'VACANT'])
                {
                  'status': status,
                  'room_id': 'room-1',
                  'rooms': {'location_id': 'loc-1'},
                },
            ]);
          case 'staff':
            if (select == 'id') {
              return response(request, [
                {'id': 'leave-1'},
              ]);
            }
            if (select == 'id,bed_assignments(staff_id)') {
              return response(request, [
                {'id': 'leave-1', 'bed_assignments': []},
                {
                  'id': 'leave-2',
                  'bed_assignments': [
                    {'staff_id': 'leave-2'},
                  ],
                },
              ]);
            }
            return response(request, [
              {
                'id': 'staff-1',
                'staff_id': 'S1',
                'name': staffName,
                'status': 'Active',
                'bed_assignments': [
                  {
                    'beds': {
                      'bed_code': 'B1',
                      'rooms': {
                        'locations': {'name': 'Main Location'},
                      },
                    },
                  },
                ],
              },
              {
                'id': 'staff-2',
                'staff_id': 'S2',
                'name': 'Bob',
                'status': 'Active',
                'auth_user_id': 'supervisor-1',
                'bed_assignments': [],
              },
            ]);
          case 'user_roles':
            return response(request, [
              {
                'user_id': 'supervisor-1',
                'role': 'supervisor',
                'location_ids': ['loc-1'],
              },
            ]);
          case 'get_admin_users':
            return failAdmins
                ? response(request, {'message': 'Unavailable'}, status: 400)
                : response(request, []);
          case 'pending_changes':
            final status = request.url.queryParameters['status'];
            return response(request, [
              for (final state in ['pending', 'approved'])
                if (status == null || status == 'eq.$state')
                  {
                    'id': state,
                    'submitted_by': 'user-1',
                    'change_type': 'shift_request',
                    'status': state,
                    'payload': {'staff_id': 'staff-1'},
                    'created_at': '2026-07-01T00:00:00Z',
                  },
            ]);
          default:
            throw StateError('Unexpected request: ${request.url}');
        }
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    requests.clear();
    responseGate = null;
    failLocations = false;
    failAdmins = false;
    staffName = 'Alice';
  });
  tearDown(() {
    if (responseGate != null && !responseGate!.isCompleted) {
      responseGate!.complete();
    }
  });

  test(
    'location and bed reads start together and preserve occupancy counts',
    () async {
      responseGate = Completer<void>();
      final read = LocationService().getAll();
      await Future<void>.delayed(Duration.zero);
      expect(requests.map((r) => r.url.pathSegments.last).toSet(), {
        'locations',
        'beds',
      });
      responseGate!.complete();
      final locations = await read;
      expect(locations.single.totalBeds, 3);
      expect(locations.single.occupiedBeds, 2);
      expect(locations.single.vacantBeds, 1);
      expect(locations.single.onLeaveBeds, 1);
    },
  );

  test(
    'overlapping location loads share requests; later refresh reads fresh data',
    () async {
      final provider = AppProvider();
      addTearDown(provider.dispose);
      responseGate = Completer<void>();
      final first = provider.loadLocations(reuseInFlight: true);
      final second = provider.loadLocations(reuseInFlight: true);
      expect(identical(first, second), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(requests, hasLength(3));
      // A refresh after an edit must not reuse a read that started before it.
      final fresh = provider.loadLocations();
      expect(identical(first, fresh), isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(requests, hasLength(6));
      responseGate!.complete();
      await Future.wait([first, second, fresh]);
      expect(provider.totalBeds, 3);
      expect(provider.totalOnLeave, 1);
      await provider.loadLocations();
      expect(requests, hasLength(9));
    },
  );

  test('a failed shared load can be retried', () async {
    final provider = AppProvider();
    addTearDown(provider.dispose);
    failLocations = true;
    await expectLater(
      provider.loadLocations(),
      throwsA(isA<PostgrestException>()),
    );
    failLocations = false;
    await provider.loadLocations();
    expect(provider.locations.single.name, 'Main Location');
    expect(requests, hasLength(6));
  });

  test(
    'pending status is filtered by Supabase and unfiltered history remains available',
    () async {
      final service = PendingService();
      final pending = await service.getAll(status: 'pending');
      expect(pending.map((change) => change.status), ['pending']);
      expect(requests.last.url.queryParameters['status'], 'eq.pending');
      final all = await service.getAll();
      expect(all, hasLength(2));
      expect(requests.last.url.queryParameters.containsKey('status'), isFalse);
    },
  );

  test(
    'local staff search preserves name, ID, bed, location and status matches',
    () {
      final staff = [
        const StaffModel(
          id: '1',
          staffId: 'ID-1',
          name: 'Alice',
          status: 'Active',
          currentBedCode: 'BED-9',
          currentLocationName: 'Main Location',
        ),
        const StaffModel(
          id: '2',
          staffId: 'ID-2',
          name: 'Bob',
          status: 'On Leave',
        ),
      ];
      for (final search in ['ALICE', 'id-1', 'bed-9', 'main']) {
        expect(StaffService.filter(staff, search: search).single.id, '1');
      }
      expect(StaffService.filter(staff, status: 'On Leave').single.id, '2');
      expect(
        StaffService.filter(staff, search: 'Alice', status: 'On Leave'),
        isEmpty,
      );
      expect(StaffService.filter(staff), hasLength(2));
      expect(staff, hasLength(2));
    },
  );

  testWidgets(
    'admin directory starts independent reads together and searches without requests',
    (tester) async {
      responseGate = Completer<void>();
      final provider = _AdminProvider();
      addTearDown(provider.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: provider,
          child: const MaterialApp(home: StaffListScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 20));
      // All requests must start before any HTTP response is released.
      expect(requests, hasLength(8));
      expect(
        requests.where(
          (r) =>
              r.url.pathSegments.last == 'staff' &&
              (r.url.queryParameters['select'] ?? '').startsWith('*'),
        ),
        hasLength(1),
      );
      responseGate!.complete();
      await tester.pumpAndSettle();
      expect(provider.staff, hasLength(2));
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      final reads = requests.length;
      await tester.enterText(find.byType(TextField), 'ALICE');
      await tester.pumpAndSettle();
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsNothing);
      expect(requests, hasLength(reads));
      await tester.enterText(find.byType(TextField), 'Main');
      await tester.pumpAndSettle();
      expect(find.text('Alice'), findsOneWidget);
      expect(requests, hasLength(reads));
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();
      expect(find.text('Bob'), findsOneWidget);
      expect(requests, hasLength(reads));
      staffName = 'Updated Alice';
      final refresh = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator).first,
      );
      await refresh.onRefresh();
      await tester.pumpAndSettle();
      expect(find.text('Updated Alice'), findsOneWidget);
      expect(provider.staff.first.name, 'Updated Alice');
      expect(requests.length, greaterThan(reads));
    },
  );

  testWidgets('directory still loads staff when optional admin lookup fails', (
    tester,
  ) async {
    failAdmins = true;
    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>(
        create: (_) => _AdminProvider(),
        child: const MaterialApp(home: StaffListScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
  });
}
