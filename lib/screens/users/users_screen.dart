// lib/screens/users/users_screen.dart  (Admin only)

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';
import '../../models/location.dart';
import '../../models/room.dart';
import '../../models/bed.dart';
import '../../services/room_service.dart';
import '../../services/bed_service.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _staffIdCtrl = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _nameCtrl    = TextEditingController();
  String _selectedRole = 'staff';
  bool _loading = false;
  String? _message;

  LocationModel? _selectedLocation;
  RoomModel? _selectedRoom;
  BedModel? _selectedBed;

  List<RoomModel> _rooms = [];
  List<BedModel> _beds = [];
  bool _loadingDropdowns = false;

  @override
  void dispose() {
    _staffIdCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _onLocationChanged(LocationModel? loc) async {
    if (loc == null) return;
    setState(() {
      _selectedLocation = loc;
      _selectedRoom = null;
      _selectedBed = null;
      _rooms = [];
      _beds = [];
      _loadingDropdowns = true;
    });
    try {
      final rooms = await RoomService().getByLocation(loc.id);
      setState(() {
        _rooms = rooms;
      });
    } catch (e) {
      setState(() => _message = '✗ Error loading rooms: $e');
    } finally {
      setState(() => _loadingDropdowns = false);
    }
  }

  Future<void> _onRoomChanged(RoomModel? room) async {
    if (room == null) return;
    setState(() {
      _selectedRoom = room;
      _selectedBed = null;
      _beds = [];
      _loadingDropdowns = true;
    });
    try {
      final beds = await BedService().getByRoom(room.id);
      setState(() {
        _beds = beds.where((b) => b.status == 'VACANT').toList();
      });
    } catch (e) {
      setState(() => _message = '✗ Error loading beds: $e');
    } finally {
      setState(() => _loadingDropdowns = false);
    }
  }

  void _onBedChanged(BedModel? bed) {
    if (bed == null) return;
    setState(() {
      _selectedBed = bed;
      _passCtrl.text = bed.bedCode;
    });
  }

  Future<void> _createAccount() async {
    final id   = _staffIdCtrl.text.trim();
    final pass = _passCtrl.text;
    final name = _nameCtrl.text.trim();
    if (id.isEmpty || pass.isEmpty || name.isEmpty) {
      setState(() => _message = '✗ All fields are required.');
      return;
    }

    if (pass.length < 6) {
      setState(() => _message = '✗ Password must be at least 6 characters long.');
      return;
    }
    
    if (_selectedRole == 'admin' && !id.contains('@')) {
      setState(() => _message = '✗ Admin accounts must use a valid email address.');
      return;
    }

    if (_selectedRole == 'staff' && _selectedBed == null) {
      setState(() => _message = '✗ Please select a Location, Room, and Bed.');
      return;
    }

    setState(() { _loading = true; _message = null; });
    try {
      final provider = context.read<AppProvider>();
      await provider.authService.createAccount(
        identifier:  id,
        displayName: name,
        password:    pass,
        role:        _selectedRole,
        selectedBedId: _selectedRole == 'staff' ? _selectedBed?.id : null,
      );
      
      // Reload provider data to update stats and list
      await provider.init();

      setState(() {
        _message = '✓ $_selectedRole account created and bed assigned for $name ($id)';
        _staffIdCtrl.clear();
        _passCtrl.clear();
        _nameCtrl.clear();
        _selectedLocation = null;
        _selectedRoom = null;
        _selectedBed = null;
        _rooms = [];
        _beds = [];
      });
    } catch (e) {
      setState(() => _message = '✗ Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.go('/dashboard'),
          color: AppTheme.textSecondary,
        ),
        title: Text('Create Account',
            style: GoogleFonts.inter(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New Account',
                style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),

            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline, color: AppTheme.textMuted),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _selectedRole,
              dropdownColor: AppTheme.bgCard,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Account Role',
                prefixIcon: Icon(Icons.admin_panel_settings_outlined, color: AppTheme.textMuted),
              ),
              items: const [
                DropdownMenuItem(value: 'staff', child: Text('Staff Member')),
                DropdownMenuItem(value: 'admin', child: Text('Administrator')),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _selectedRole = v;
                    _staffIdCtrl.clear();
                    _passCtrl.clear();
                    _selectedLocation = null;
                    _selectedRoom = null;
                    _selectedBed = null;
                    _rooms = [];
                    _beds = [];
                  });
                }
              },
            ),
            if (_selectedRole == 'staff') ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<LocationModel>(
                value: _selectedLocation,
                dropdownColor: AppTheme.bgCard,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Select Location',
                  prefixIcon: Icon(Icons.location_on_outlined, color: AppTheme.textMuted),
                ),
                items: provider.locations.map((loc) {
                  return DropdownMenuItem<LocationModel>(
                    value: loc,
                    child: Text('${loc.name} (${loc.id})'),
                  );
                }).toList(),
                onChanged: _loadingDropdowns ? null : _onLocationChanged,
              ),
              if (_selectedLocation != null) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<RoomModel>(
                  value: _selectedRoom,
                  dropdownColor: AppTheme.bgCard,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Select Room',
                    prefixIcon: Icon(Icons.meeting_room_outlined, color: AppTheme.textMuted),
                  ),
                  items: _rooms.map((room) {
                    return DropdownMenuItem<RoomModel>(
                      value: room,
                      child: Text('${room.roomNumber} (${room.roomCode})'),
                    );
                  }).toList(),
                  onChanged: _loadingDropdowns ? null : _onRoomChanged,
                ),
              ],
              if (_selectedRoom != null) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<BedModel>(
                  value: _selectedBed,
                  dropdownColor: AppTheme.bgCard,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Select Bed (Vacant)',
                    prefixIcon: Icon(Icons.bed_outlined, color: AppTheme.textMuted),
                  ),
                  items: _beds.map((bed) {
                    return DropdownMenuItem<BedModel>(
                      value: bed,
                      child: Text('${bed.bedCode} (${bed.position})'),
                    );
                  }).toList(),
                  onChanged: _loadingDropdowns ? null : _onBedChanged,
                ),
              ],
              if (_loadingDropdowns) ...[
                const SizedBox(height: 10),
                const Center(
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _staffIdCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: _selectedRole == 'admin' 
                    ? 'Email Address (login username)' 
                    : 'Occupant ID (login username)',
                hintText: _selectedRole == 'admin' 
                    ? 'e.g. admin@sgs.com' 
                    : 'e.g. 1325 or LS6080',
                prefixIcon: const Icon(Icons.badge_outlined, color: AppTheme.textMuted),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: _selectedRole == 'admin'
                    ? 'Password'
                    : 'Default Password (auto-filled on bed select)',
                hintText: _selectedRole == 'admin'
                    ? 'Minimum 6 characters'
                    : 'Select a bed to auto-fill password',
                prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textMuted),
              ),
            ),
            const SizedBox(height: 24),

            if (_message != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _message!.startsWith('✓')
                      ? AppTheme.success.withValues(alpha: 0.1)
                      : AppTheme.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _message!.startsWith('✓')
                          ? AppTheme.success.withValues(alpha: 0.3)
                          : AppTheme.danger.withValues(alpha: 0.3)),
                ),
                child: Text(_message!,
                    style: GoogleFonts.inter(
                        color: _message!.startsWith('✓')
                            ? AppTheme.success
                            : AppTheme.danger,
                        fontSize: 13)),
              ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _createAccount,
                icon: _loading
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.person_add_rounded),
                label: const Text('Create Account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
