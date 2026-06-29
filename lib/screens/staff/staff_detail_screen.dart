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
    } catch (e) {
      debugPrint('Error: $e');
    }
    setState(() => _loading = false);
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
        backgroundColor: AppTheme.bgDark,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    if (_staff == null) {
      return Scaffold(
        backgroundColor: AppTheme.bgDark,
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
    final statusColor = AppTheme.staffStatusColor(staff.status);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        leading: BackButton(
            onPressed: () => context.go('/staff'), color: AppTheme.textSecondary),
        title: Text('Staff Profile',
            style: GoogleFonts.inter(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        actions: [
          if (isAdmin)
            PopupMenuButton<String>(
              color: AppTheme.bgCard,
              icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
              onSelected: (val) async {
                if (val == 'leave') {
                  await _staffService.markOnLeave(staff.id);
                  _load();
                } else if (val == 'returned') {
                  await _staffService.markReturned(staff.id);
                  _load();
                }
              },
              itemBuilder: (_) => [
                if (staff.status == 'Active')
                  PopupMenuItem(
                    value: 'leave',
                    child: Text('Mark On Leave',
                        style: GoogleFonts.inter(color: AppTheme.textPrimary)),
                  ),
                if (staff.status == 'On Leave')
                  PopupMenuItem(
                    value: 'returned',
                    child: Text('Mark Returned',
                        style: GoogleFonts.inter(color: AppTheme.textPrimary)),
                  ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, AppTheme.accent],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(initials,
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 22,
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
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('ID: ${staff.staffId}',
                          style: GoogleFonts.inter(
                              color: AppTheme.textMuted, fontSize: 13)),
                      const SizedBox(height: 8),
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
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

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
          const SizedBox(height: 16),

          // Shift history
          Text('Shift History',
              style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (_shifts.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Center(
                child: Text('No shift history',
                    style: GoogleFonts.inter(color: AppTheme.textMuted)),
              ),
            )
          else
            ..._shifts.map((shift) => _ShiftHistoryTile(shift: shift)),
        ],
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
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: children
            .expand((w) => [w, const Divider(color: AppTheme.divider, height: 16)])
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
        Icon(icon, color: AppTheme.primary, size: 16),
        const SizedBox(width: 10),
        Text('$label: ',
            style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13)),
        Expanded(
          child: Text(value,
              style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),

              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.swap_horiz_rounded, color: AppTheme.primary, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${shift.fromBedCode ?? "–"} → ${shift.toBedCode ?? "–"}',
                  style: GoogleFonts.inter(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
                if (shift.reason != null && shift.reason!.isNotEmpty)
                  Text(shift.reason!,
                      style: GoogleFonts.inter(
                          color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Text(
            DateFormat('dd MMM yy').format(shift.shiftDate),
            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
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
