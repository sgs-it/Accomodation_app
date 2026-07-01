import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';


enum UserRole { admin, staff, unknown }

class AuthService {
  final _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  /// Resolves the login identifier to a full email.
  /// If the input already contains '@' it's used as-is (admin).
  /// Otherwise, spaces and special chars are stripped and @staff.sgs.com is appended.
  static String resolveEmail(String input) {
    if (input.contains('@')) return input.trim();
    final clean = input.trim().replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    return '$clean@staff.sgs.com';
  }

  Future<void> signIn({required String identifier, required String password}) async {
    final email = resolveEmail(identifier);
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<UserRole> getCurrentRole() async {
    final user = currentUser;
    if (user == null) return UserRole.unknown;

    final resp = await _client
        .from('user_roles')
        .select('role')
        .eq('user_id', user.id)
        .maybeSingle();

    if (resp == null) return UserRole.unknown;
    final role = resp['role'] as String?;
    if (role == 'admin') return UserRole.admin;
    if (role == 'staff') return UserRole.staff;
    return UserRole.unknown;
  }

  /// Get the linked staff record for the currently logged-in staff user
  Future<Map<String, dynamic>?> getMyStaffRecord() async {
    final user = currentUser;
    if (user == null) return null;
    return await _client
        .from('staff')
        .select('*, bed_assignments(bed:beds(id, bed_code, position, room:rooms(id, room_number, room_code, location:locations(id, name))))')
        .eq('auth_user_id', user.id)
        .maybeSingle();
  }

  /// Admin creates a new account (staff or admin)
  Future<void> createAccount({
    required String identifier,
    required String displayName,
    required String password,
    required String role,
    String? selectedBedId,
  }) async {
    final email = role == 'admin' ? identifier : resolveEmail(identifier);

    final tempClient = SupabaseClient(
      supabaseUrl,
      supabaseAnonKey,
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );

    final result = await tempClient.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );

    final newUserId = result.user?.id;
    if (newUserId == null) throw Exception('Failed to create account');

    await _client.from('user_roles').upsert(
      {'user_id': newUserId, 'role': role},
      onConflict: 'user_id',
    );

    if (role == 'staff') {
      // 1. Create staff profile record directly
      final staffResponse = await _client
          .from('staff')
          .insert({
            'staff_id': identifier,
            'name': displayName,
            'status': 'Active',
            'auth_user_id': newUserId,
            'nationality': 'Unknown',
          })
          .select('id')
          .single();

      final staffUuid = staffResponse['id'] as String;

      // 2. If a bed is selected, assign it
      if (selectedBedId != null) {
        await _client.from('bed_assignments').delete().eq('bed_id', selectedBedId);
        await _client.from('bed_assignments').insert({
          'bed_id': selectedBedId,
          'staff_id': staffUuid,
        });

        // 3. Set bed status to FULL
        await _client.from('beds').update({'status': 'FULL'}).eq('id', selectedBedId);
      }
    }

    tempClient.dispose();
  }

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}
