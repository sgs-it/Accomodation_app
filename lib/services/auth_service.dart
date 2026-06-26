// lib/services/auth_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';

enum UserRole { admin, viewer, unknown }

class AuthService {
  final _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  Future<void> signIn({required String email, required String password}) async {
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
    if (role == 'viewer') return UserRole.viewer;
    return UserRole.unknown;
  }

  /// Admin creates a new viewer account
  Future<void> createViewer({
    required String email,
    required String password,
    required String displayName,
  }) async {
    // Use admin API (requires service role or admin function)
    // We'll use a Supabase Edge Function or the admin client approach
    // For now we use signUp + assign role
    final result = await _client.auth.admin.createUser(AdminUserAttributes(
      email: email,
      password: password,
      emailConfirm: true,
      userMetadata: {'display_name': displayName},
    ));

    final newUserId = result.user?.id;
    if (newUserId == null) throw Exception('Failed to create user');

    await _client.from('user_roles').insert({
      'user_id': newUserId,
      'role': 'viewer',
    });
  }

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}
