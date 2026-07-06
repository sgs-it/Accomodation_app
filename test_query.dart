import 'dart:convert';
import 'dart:io';

void main() async {
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJobXplYnV2a3NudG9zYW9nemV0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI0NjUxMjUsImV4cCI6MjA5ODA0MTEyNX0.6PRqD_9AU8mQmC4LmmeWEfsaKHeRnmFkjuXyFbW4vnM';
  final supabaseUrl = 'https://bhmzebuvksntosaogzet.supabase.co';
  
  final client = HttpClient();
  try {
    final loginUrl = '$supabaseUrl/auth/v1/token?grant_type=password';
    final loginReq = await client.postUrl(Uri.parse(loginUrl));
    loginReq.headers.set('apikey', anonKey);
    loginReq.headers.set('Content-Type', 'application/json');
    loginReq.write(jsonEncode({'email': 'sgsit2024@gmail.com', 'password': 'sebil364'}));
    final loginRes = await loginReq.close();
    final loginResBody = await loginRes.transform(utf8.decoder).join();
    final token = jsonDecode(loginResBody)['access_token'] as String;
    
    final staffData = await client
        .from('staff')
        .select()
        .eq('status', 'On Leave')
        .order('name', ascending: true);

    final staffIds = staffData.map((s) => s['id']).toList();
    List<dynamic> activeAssignments = [];
    if (staffIds.isNotEmpty) {
      activeAssignments = await client
          .from('bed_assignments')
          .select('staff_id')
          .filter('staff_id', 'in', staffIds);
    }
    final assignedStaffIds = activeAssignments.map((a) => a['staff_id']).toSet();

    final result = [];
    for (final staff in staffData) {
      if (!assignedStaffIds.contains(staff['id'])) {
        result.add(staff);
      }
    }
    
    print('Staff on leave: ${staffData.length}');
    print('Unassigned staff: ${result.length}');
  } catch(e) {
    print('Exception: $e');
  } finally {
    client.close();
  }
}
