// lib/screens/staff/staff_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/staff.dart';
import '../../models/shift_history.dart';
import '../../providers/app_provider.dart';
import '../../services/staff_service.dart';
import '../../services/shift_service.dart';

class StaffDetailScreen extends StatefulWidget {
  final String staffId;
  const StaffDetailScreen({super.key, required this.staffId});

  @override
  State<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends State<StaffDetailScreen> {
  final _staffService = StaffService();
  final _shiftService = ShiftService();
  bool _loading = true;
  StaffModel? _staff;
  List<ShiftHistoryModel> _shifts = [];
  String? _currentBed;

  bool _isSupervisor = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _staff = await _staffService.getById(widget.staffId);
      _shifts = await _shiftService.getAll(staffId: widget.staffId);
      _currentBed = await _queryCurrentBed(widget.staffId);
      if (_staff != null) {
        _isSupervisor = await _checkIfSupervisor(_staff!.id);
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
    setState(() => _loading = false);
  }

  Future<bool> _checkIfSupervisor(String staffDbId) async {
    try {
      final supabase = StaffServiceHelper.client;
      // 1. Get auth_user_id from staff
      final staffResp = await supabase.from('staff').select('auth_user_id').eq('id', staffDbId).maybeSingle();
      if (staffResp == null || staffResp['auth_user_id'] == null) return false;
      
      // 2. Check if role is supervisor
      final authUserId = staffResp['auth_user_id'] as String;
      final roleResp = await supabase.from('user_roles').select('role').eq('user_id', authUserId).maybeSingle();
      if (roleResp != null && roleResp['role'] == 'supervisor') {
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<String?> _queryCurrentBed(String staffId) async {
    try {
      final supabase = StaffServiceHelper.client;
      final resp = await supabase
          .from('bed_assignments')
          .select('beds(bed_code)')
          .eq('staff_id', staffId)
          .maybeSingle();
      if (resp != null && resp['beds'] != null) {
        return (resp['beds'] as Map<String, dynamic>)['bed_code'] as String?;
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isAdmin = provider.isAdmin;

    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6))),
      );
    }

    if (_staff == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(leading: BackButton(onPressed: () => context.go('/staff'))),
        body: const Center(child: Text('Staff not found')),
      );
    }

    final staff = _staff!;
    String getInitials(String name) {
      if (name.trim().isEmpty) return '?';
      final parts = name.trim().split(' ').where((w) => w.isNotEmpty).take(2);
      if (parts.isEmpty) return '?';
      return parts.map((w) => w[0].toUpperCase()).join();
    }
    final initials = getInitials(staff.name);
    
    // Status color
    Color statusColor = const Color(0xFF10B981); // Green
    if (staff.status == 'On Leave') {
      statusColor = const Color(0xFFF59E0B); // Amber
    } else if (staff.status == 'Inactive') {
      statusColor = const Color(0xFFEF4444); // Red
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B5CF6),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: BackButton(
            onPressed: () => context.go('/staff'), color: Colors.white),
        title: Text('Staff Profile',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.w700)),
        actions: [
          if (isAdmin)
            PopupMenuButton<String>(
              color: Colors.white,
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (val) async {
                if (val == 'leave') {
                  await _staffService.markOnLeave(staff.id);
                  _load();
                } else if (val == 'returned') {
                  await _staffService.markReturned(staff.id);
                  _load();
                } else if (val == 'edit') {
                  _showEditStaffDialog(context, staff);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit Details',
                      style: GoogleFonts.inter(color: Colors.black87)),
                ),
                if (staff.status == 'Active')
                  PopupMenuItem(
                    value: 'leave',
                    child: Text('Mark On Leave',
                        style: GoogleFonts.inter(color: Colors.black87)),
                  ),
                if (staff.status == 'On Leave')
                  PopupMenuItem(
                    value: 'returned',
                    child: Text('Mark Returned',
                        style: GoogleFonts.inter(color: Colors.black87)),
                  ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
        children: [
          // Profile header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF4C1D95)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(initials,
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(staff.name,
                          style: GoogleFonts.inter(
                              color: Colors.black87,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('ID: ${staff.staffId}',
                          style: GoogleFonts.inter(
                              color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(staff.status,
                                style: GoogleFonts.inter(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ),
                          if (_isSupervisor) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('Supervisor',
                                  style: GoogleFonts.inter(
                                      color: const Color(0xFF8B5CF6),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Details
          _InfoCard(children: [
            _InfoRow(icon: Icons.badge_outlined, label: 'Staff ID', value: staff.staffId),
            if (staff.phone != null)
              _InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: staff.phone!),
            if (staff.nationality != null)
              _InfoRow(icon: Icons.flag_outlined, label: 'Nationality', value: staff.nationality!),
            if (_currentBed != null)
              _InfoRow(icon: Icons.bed_rounded, label: 'Current Bed', value: _currentBed!),
          ]),
          const SizedBox(height: 24),

          // Shift history
          Text('Shift History',
              style: GoogleFonts.inter(
                  color: Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_shifts.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Center(
                child: Text('No shift history',
                    style: GoogleFonts.inter(color: Colors.black54)),
              ),
            )
          else
            ..._shifts.map((shift) => _ShiftHistoryTile(shift: shift)),
        ],
      ),
    );
  }

  void _showEditStaffDialog(BuildContext ctx, StaffModel staff) {
    final nameCtrl = TextEditingController(text: staff.name);
    final staffIdCtrl = TextEditingController(text: staff.staffId);
    final phoneCtrl = TextEditingController(text: staff.phone ?? '');
    final nationalityCtrl = TextEditingController(text: staff.nationality ?? '');
    final passwordCtrl = TextEditingController();
    String status = staff.status;

    showDialog(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setS) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Edit Staff Details',
              style: GoogleFonts.inter(color: Colors.black87, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.black87),
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: staffIdCtrl,
                  style: const TextStyle(color: Colors.black87),
                  decoration: const InputDecoration(labelText: 'Staff ID'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.black87),
                  decoration: const InputDecoration(labelText: 'Phone (optional)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nationalityCtrl,
                  style: const TextStyle(color: Colors.black87),
                  decoration: const InputDecoration(labelText: 'Nationality (optional)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordCtrl,
                  style: const TextStyle(color: Colors.black87),
                  decoration: const InputDecoration(labelText: 'New Password (optional)', hintText: 'Leave empty to keep current'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: status,
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: Colors.black87),
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'Active', child: Text('Active')),
                    DropdownMenuItem(value: 'On Leave', child: Text('On Leave')),
                    DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                  ],
                  onChanged: (v) => setS(() => status = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: Text('Cancel',
                  style: GoogleFonts.inter(color: Colors.black54)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final sId = staffIdCtrl.text.trim();
                if (name.isEmpty || sId.isEmpty) return;

                Navigator.pop(dCtx);
                try {
                  await _staffService.update(
                    staff.id, 
                    {
                      'name': name,
                      'staff_id': sId,
                      'phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                      'nationality': nationalityCtrl.text.trim().isEmpty ? null : nationalityCtrl.text.trim(),
                      'status': status,
                    },
                    newPassword: passwordCtrl.text.trim().isEmpty ? null : passwordCtrl.text.trim(),
                  );
                  await _load();
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Error updating staff: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: children
            .expand((w) => [w, Divider(color: Colors.grey.shade200, height: 24)])
            .toList()
          ..removeLast(),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF8B5CF6), size: 18),
        const SizedBox(width: 12),
        Text('$label: ',
            style: GoogleFonts.inter(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w500)),
        Expanded(
          child: Text(value,
              style: GoogleFonts.inter(
                  color: Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _ShiftHistoryTile extends StatelessWidget {
  final ShiftHistoryModel shift;
  const _ShiftHistoryTile({required this.shift});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF8B5CF6), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${shift.fromBedCode ?? "–"} → ${shift.toBedCode ?? "–"}',
                  style: GoogleFonts.inter(
                      color: Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                if (shift.reason != null && shift.reason!.isNotEmpty)
                  Text(shift.reason!,
                      style: GoogleFonts.inter(
                          color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),
          Text(
            DateFormat('dd MMM yy').format(shift.shiftDate),
            style: GoogleFonts.inter(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// Helper to access Supabase client
class StaffServiceHelper {
  static SupabaseClient get client => Supabase.instance.client;
}
