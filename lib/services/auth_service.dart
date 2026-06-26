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
    // We cannot use admin.createUser from the client with just the anon key.
    // Instead, we use a temporary client to sign up the user without logging out the admin.
    final tempClient = SupabaseClient(
      _client.auth.currentSession != null 
          ? _client.rest.url.replaceAll('/rest/v1', '') 
          : 'https://bhmzebuvksntosaogzet.supabase.co',
      _client.rest.headers['apikey'] ?? '',
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
      ),
    );

    final result = await tempClient.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );

    final newUserId = result.user?.id;
    if (newUserId == null) throw Exception('Failed to create user');

    await _client.from('user_roles').insert({
      'user_id': newUserId,
      'role': 'viewer',
    });
    
    tempClient.dispose();
  }

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}

