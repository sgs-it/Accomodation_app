// lib/providers/app_provider.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/location.dart';
import '../models/room.dart';
import '../models/staff.dart';
import '../models/shift_history.dart';
import '../services/location_service.dart';
import '../services/room_service.dart';
import '../services/staff_service.dart';
import '../services/shift_service.dart';
import '../services/auth_service.dart';
import '../services/pending_service.dart';
import '../services/fcm_service.dart';
import 'package:flutter/foundation.dart';

class AppProvider extends ChangeNotifier {
  final _locationService = LocationService();
  final _roomService     = RoomService();
  final _staffService    = StaffService();
  final _shiftService    = ShiftService();
  final _authService     = AuthService();
  final _pendingService  = PendingService();

  // State
  List<LocationModel>    _locations = [];
  List<RoomModel>        _rooms     = [];
  List<StaffModel>       _staff     = [];
  List<ShiftHistoryModel> _shifts   = [];
  List<PendingChange>    _pending   = [];
  UserRole _role   = UserRole.unknown;
  bool     _loading = false;
  String?  _error;
  // Current logged-in staff record (for staff role)
  Map<String, dynamic>? _myStaffRecord;
  int _pendingCount = 0;
  int _totalOnLeaveStaff = 0;

  // Getters
  List<LocationModel>    get locations     => _locations;
  int                    get totalOnLeaveStaff => _totalOnLeaveStaff;
  List<RoomModel>        get rooms         => _rooms;
  List<StaffModel>       get staff         => _staff;
  List<ShiftHistoryModel> get shifts       => _shifts;
  List<PendingChange>    get pendingChanges => _pending;
  UserRole               get role          => _role;
  bool                   get loading       => _loading;
  String?                get error         => _error;
  bool get isAdmin => _role == UserRole.admin;
  bool get isStaff => _role == UserRole.staff;
  AuthService    get authService    => _authService;
  PendingService get pendingService => _pendingService;
  Map<String, dynamic>? get myStaffRecord => _myStaffRecord;
  int get pendingCount => _pendingCount;

  void _setLoading(bool v) { _loading = v; notifyListeners(); }
  void _setError(String? e) { _error = e; notifyListeners(); }

  Future<void> init() async {
    _setLoading(true);
    try {
      _role = await _authService.getCurrentRole();
      
      // Setup push notifications
      if (!kIsWeb) {
        await FcmService().setupFCM();
      }

      if (isStaff) {
        _myStaffRecord = await _authService.getMyStaffRecord();
      }
      await Future.wait([
        loadLocations(),
        loadStaff(),
        loadShifts(),
      ]);
      if (isAdmin) await refreshPendingCount();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadLocations() async {
    _locations = await _locationService.getAll();
    try {
      final staffLeaveResp = await Supabase.instance.client
          .from('staff')
          .select('id')
          .eq('status', 'On Leave');
      _totalOnLeaveStaff = (staffLeaveResp as List).length;
    } catch (e) {
      debugPrint('Error fetching on leave staff count: $e');
    }
    notifyListeners();
  }

  Future<void> loadRoomsForLocation(String locationId) async {
    _rooms = await _roomService.getByLocation(locationId);
    notifyListeners();
  }

  Future<void> loadStaff({String? search, String? status, String? locationId}) async {
    _staff = await _staffService.getAll(
        search: search, status: status, locationId: locationId);
    notifyListeners();
  }

  Future<void> loadShifts({String? staffId}) async {
    _shifts = await _shiftService.getAll(staffId: staffId);
    notifyListeners();
  }

  Future<void> loadPendingChanges({String? status}) async {
    _pending = await _pendingService.getAll(status: status);
    notifyListeners();
  }

  Future<void> refreshPendingCount() async {
    _pendingCount = await _pendingService.getPendingCount();
    notifyListeners();
  }

  Future<void> approveChange(PendingChange change, {String? note}) async {
    await _pendingService.approve(change, note: note);
    await Future.wait([loadPendingChanges(), refreshPendingCount(), loadLocations(), loadStaff()]);
  }

  Future<void> rejectChange(PendingChange change, {required String reason}) async {
    await _pendingService.reject(change, reason: reason);
    await Future.wait([loadPendingChanges(), refreshPendingCount()]);
  }

  // Summaries for Dashboard
  int get totalBeds     => _locations.fold(0, (s, l) => s + l.totalBeds);
  int get totalOccupied => _locations.fold(0, (s, l) => s + l.occupiedBeds);
  int get totalVacant   => _locations.fold(0, (s, l) => s + l.vacantBeds);
  int get totalOnLeave  => _totalOnLeaveStaff;
}
