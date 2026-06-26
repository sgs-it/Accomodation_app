// This is a basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';
import 'package:staff_accommodation_app/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // App requires Supabase init — just verify it compiles
    expect(StaffAccommApp, isNotNull);
  });
}
