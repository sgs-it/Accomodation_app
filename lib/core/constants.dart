// lib/core/constants.dart

const String supabaseUrl = 'https://bhmzebuvksntosaogzet.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJobXplYnV2a3NudG9zYW9nemV0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI0NjUxMjUsImV4cCI6MjA5ODA0MTEyNX0.6PRqD_9AU8mQmC4LmmeWEfsaKHeRnmFkjuXyFbW4vnM';

// Location codes
const List<Map<String, String>> kDefaultLocations = [
  {'id': 'AQZ', 'name': 'Al Quoz'},
  {'id': 'SNP', 'name': 'Sonapur'},
  {'id': 'JBL', 'name': 'Jebel Ali'},
  {'id': 'DIP', 'name': 'DIP'},
  {'id': 'RAK', 'name': 'Ras Al Khaimah'},
];

// Bed positions
const List<String> kBedPositions = ['LB', 'UB', 'SB'];
const Map<String, String> kBedPositionLabels = {
  'LB': 'Lower Bed',
  'UB': 'Upper Bed',
  'SB': 'Single Bed',
};

// Bed statuses
const List<String> kBedStatuses = ['VACANT', 'FULL', 'VACATION', 'MAINTENANCE'];

// Staff statuses
const List<String> kStaffStatuses = ['Active', 'On Leave', 'Inactive'];
