import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FcmService {
  final _client = Supabase.instance.client;
  final _fcm = FirebaseMessaging.instance;

  Future<void> setupFCM() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    // Request permissions
    NotificationSettings settings = await _fcm.requestPermission();
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      String? token = await _fcm.getToken();
      if (token != null) {
        await _saveToken(token);
      }

      // Listen for token refreshes
      _fcm.onTokenRefresh.listen(_saveToken);
    }
  }

  Future<void> _saveToken(String token) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      await _client.from('fcm_tokens').upsert({
        'user_id': user.id,
        'token': token,
      }, onConflict: 'user_id, token');
    } catch (e) {
      print('Failed to save FCM token: $e');
    }
  }
}
