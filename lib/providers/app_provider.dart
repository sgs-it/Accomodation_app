// lib/providers/app_provider.dart

import 'package:flutter/material.dart';
import '../models/location.dart';
import '../models/room.dart';
import '../models/staff.dart';
import '../models/shift_history.dart';
import '../services/location_service.dart';
import '../services/room_service.dart';
import '../services/staff_service.dart';
import '../services/shift_service.dart';
import '../services/auth_service.dart';

class AppProvider extends ChangeNotifier {
  final _locationService = LocationService();
  final _roomService = RoomService();
  final _staffService = StaffService();
  final _shiftService = ShiftService();
  final _authService = AuthService();

  // State
  List<LocationModel> _locations = [];
  List<RoomModel> _rooms = [];
  List<StaffModel> _staff = [];
  List<ShiftHistoryModel> _shifts = [];
  UserRole _role = UserRole.unknown;
  bool _loading = false;
  String? _error;

  // Getters
  List<LocationModel> get locations => _locations;
  List<RoomModel> get rooms => _rooms;
  List<StaffModel> get staff => _staff;
  List<ShiftHistoryModel> get shifts => _shifts;
  UserRole get role => _role;
  bool get loading => _loading;
  String? get error => _error;
  bool get isAdmin => _role == UserRole.admin;
  AuthService get authService => _authService;

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  void _setError(String? e) {
    _error = e;
    notifyListeners();
  }

  Future<void> init() async {
    _setLoading(true);
    try {
      _role = await _authService.getCurrentRole();
      await Future.wait([
        loadLocations(),
        loadStaff(),
        loadShifts(),
      ]);
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadLocations() async {
    _locations = await _locationService.getAll();
    notifyListeners();
  }

  Future<void> loadRoomsForLocation(String locationId) async {
    _rooms = await _roomService.getByLocation(locationId);
    notifyListeners();
  }

  Future<void> loadStaff({String? search, String? status}) async {
    _staff = await _staffService.getAll(search: search, status: status);
    notifyListeners();
  }

  Future<void> loadShifts({String? staffId}) async {
    _shifts = await _shiftService.getAll(staffId: staffId);
    notifyListeners();
  }

  // Summaries for Dashboard
  int get totalBeds => _locations.fold(0, (sum, l) => sum + l.totalBeds);
  int get totalOccupied => _locations.fold(0, (sum, l) => sum + l.occupiedBeds);
  int get totalVacant => _locations.fold(0, (sum, l) => sum + l.vacantBeds);
  int get totalOnLeave => _locations.fold(0, (sum, l) => sum + l.onLeaveBeds);
}
