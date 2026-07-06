import 'dart:io';
import 'package:supabase/supabase.dart';

void main() async {
  final supabaseUrl = Platform.environment['SUPABASE_URL'] ?? 'http://127.0.0.1:54321';
  final supabaseKey = Platform.environment['SUPABASE_ANON_KEY'] ?? ''; // Need to get this from the app config or environment

  // Let's just read the config from the app
  final file = File('lib/core/constants.dart');
  if (await file.exists()) {
    final content = await file.readAsString();
    print("Found constants.dart: \n$content");
  } else {
    print("constants.dart not found");
  }
}
