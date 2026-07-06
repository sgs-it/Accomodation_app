import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('Triggering password reset...');
  final url = Uri.parse('https://bhmzebuvksntosaogzet.supabase.co/functions/v1/reset_staff_passwords');
  final response = await http.post(url);
  print('Status code: ${response.statusCode}');
  print('Response:');
  print(response.body);
}
