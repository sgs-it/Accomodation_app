import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/constants.dart';


enum UserRole { admin, supervisor, staff, unknown }

class AuthService {
  final _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  /// Resolves the login identifier to a full email.
  /// If the input already contains '@' it's used as-is (admin).
  /// Otherwise, spaces and special chars are stripped and @staff.sgs.com is appended.
  static String resolveEmail(String input) {
    if (input.contains('@')) return input.trim().toLowerCase();
    // Remove only whitespace, preserve hyphens/underscores, and lowercase it
    final clean = input.trim().replaceAll(RegExp(r'\s+'), '').toLowerCase();
    return '$clean@staff.sgs.com';
  }

  Future<void> signIn({required String identifier, required String password}) async {
    final email = resolveEmail(identifier);
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<Map<String, dynamic>> getCurrentRoleWithLocation() async {
    final user = currentUser;
    if (user == null) return {'role': UserRole.unknown, 'location_id': null};

    for (int i = 0; i < 3; i++) {
      final resp = await _client
          .from('user_roles')
          .select('role, location_id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (resp != null) {
        final roleStr = resp['role'] as String?;
        final locId = resp['location_id'] as String?;
        UserRole role = UserRole.unknown;
        if (roleStr == 'admin') role = UserRole.admin;
        if (roleStr == 'supervisor') role = UserRole.supervisor;
        if (roleStr == 'staff') role = UserRole.staff;
        return {'role': role, 'location_id': locId};
      }
      
      await Future.delayed(const Duration(milliseconds: 500));
    }

    return {'role': UserRole.unknown, 'location_id': null};
  }

  Future<UserRole> getCurrentRole() async {
    final data = await getCurrentRoleWithLocation();
    return data['role'] as UserRole;
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
    String? managedLocationId,
  }) async {
    final email = role == 'admin' ? identifier : resolveEmail(identifier);

    // Call Supabase REST API directly to avoid overriding the admin's session in the Flutter SDK
    final response = await http.post(
      Uri.parse('$supabaseUrl/auth/v1/signup'),
      headers: {
        'apikey': supabaseAnonKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
        'data': {'display_name': displayName},
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create account: ${response.body}');
    }

    final responseData = jsonDecode(response.body);
    final newUserId = responseData['user']?['id'] ?? responseData['id'];

    if (newUserId == null) throw Exception('Failed to create account. Response: ${response.body}');

    // Add a small delay in case there is a trigger creating the public.users row
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final roleData = {'user_id': newUserId, 'role': role};
      if (managedLocationId != null) {
        roleData['location_id'] = managedLocationId;
      }
      
      await _client.from('user_roles').upsert(
        roleData,
        onConflict: 'user_id',
      );
    } on PostgrestException catch (e) {
      if (e.code == '23503') {
        throw Exception('Account with this ID already exists, or the database trigger failed to sync the user.');
      }
      rethrow;
    }

    if (role == 'staff' || role == 'supervisor') {
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
      
      // 4. Log creation notification
      try {
        await _client.from('app_notifications').insert({
          'type': 'staff_added',
          'title': 'New Staff Added: $displayName',
          'message': 'ID: $identifier',
          'staff_id': staffUuid,
          'staff_name': displayName,
        });
      } catch (e) {
        // ignore
      }
    }
  }

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Update a user's password using the Edge Function
  Future<void> updatePassword(String userId, String newPassword) async {
    final response = await _client.functions.invoke(
      'update_password',
      body: {
        'user_id': userId,
        'password': newPassword,
      },
    );
    
    if (response.status != 200) {
      throw Exception('Failed to update password: ${response.data}');
    }
  }
}
