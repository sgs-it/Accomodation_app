// lib/screens/shifts/shift_history_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/shift_history.dart';
import '../../models/staff.dart';
import '../../providers/app_provider.dart';
import '../../services/shift_service.dart';
import '../../services/staff_service.dart';
import '../../services/bed_service.dart';
import '../../models/bed.dart';
import '../../services/pending_service.dart';
import '../../widgets/loading_skeleton.dart';

class ShiftHistoryScreen extends StatefulWidget {
  const ShiftHistoryScreen({super.key});

  @override
  State<ShiftHistoryScreen> createState() => _ShiftHistoryScreenState();
}

class _ShiftHistoryScreenState extends State<ShiftHistoryScreen>
    with SingleTickerProviderStateMixin {
  final _shiftService = ShiftService();
  bool _loading = true;
  List<ShiftHistoryModel> _shifts = [];
  List<PendingChange> _myPending = [];
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final provider = context.read<AppProvider>();
    _shifts = await _shiftService.getAll();
    if (provider.isStaff) {
      _myPending = await provider.pendingService.getMyChanges();
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isAdmin = provider.isAdmin;
    final isStaff = provider.isStaff;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Purple Header
          ClipPath(
            clipper: _HeaderClipper(),
            child: Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16, bottom: 40, left: 20, right: 20),
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF4C1D95)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          'Room Shift Log',
                          style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (isAdmin)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.add, color: Colors.white),
                            onPressed: () => _showLogShiftDialog(context),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          if (isStaff)
            Transform.translate(
              offset: const Offset(0, -20),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: TabBar(
                  controller: _tabs,
                  indicatorColor: const Color(0xFF8B5CF6),
                  labelColor: const Color(0xFF8B5CF6),
                  unselectedLabelColor: Colors.black54,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                  tabs: const [
                    Tab(text: 'Shift History'),
                    Tab(text: 'My Requests'),
                  ],
                ),
              ),
            ),

          Expanded(
            child: Transform.translate(
              offset: Offset(0, isStaff ? -10 : -20),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(children: [SkeletonCard(), SkeletonCard()]),
                    )
                  : isStaff
                      ? TabBarView(
                          controller: _tabs,
                          children: [
                            _buildShiftList(isAdmin),
                            _buildMyRequests(provider),
                          ],
                        )
                      : _buildShiftList(isAdmin),
            ),
          ),
        ],
      ),
      floatingActionButton: isStaff
          ? FloatingActionButton.extended(
              onPressed: () => _showShiftRequestDialog(context, provider),
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white),
              label: Text('Request Shift',
                  style: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
    );
  }

  Widget _buildShiftList(bool isAdmin) {
    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: Colors.white,
      onRefresh: _load,
      child: _shifts.isEmpty
          ? _EmptyShifts()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
              itemCount: _shifts.length,
              itemBuilder: (ctx, i) => _ShiftCard(
                shift: _shifts[i],
                isAdmin: isAdmin,
                onDelete: isAdmin
                    ? () async {
                        await _shiftService.delete(_shifts[i].id);
                        _load();
                      }
                    : null,
              ),
            ),
    );
  }

  Widget _buildMyRequests(AppProvider provider) {
    final shiftReqs = _myPending.where((c) => c.changeType == 'shift_request').toList();

    if (shiftReqs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pending_actions_outlined,
                size: 56, color: AppTheme.textMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text('No pending requests',
                style: GoogleFonts.inter(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Tap the button below to request a room shift',
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: shiftReqs.length,
      itemBuilder: (ctx, i) => _MyRequestCard(change: shiftReqs[i]),
    );
  }

  void _showLogShiftDialog(BuildContext ctx) async {
    final staffService = StaffService();
    final bedService = BedService();

    final allStaff = await staffService.getAll();
    final allBeds = await bedService.getVacantBeds();

    StaffModel? selectedStaff;
    BedModel? fromBed;
    BedModel? toBed;
    DateTime shiftDate = DateTime.now();
    final reasonCtrl = TextEditingController();

    if (!ctx.mounted) return;

    showDialog(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setS) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Log Room Shift',
              style: GoogleFonts.inter(color: AppTheme.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<StaffModel>(
                  isExpanded: true,
                  dropdownColor: AppTheme.bgCard,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Staff Member'),
                  items: allStaff
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text('${s.name} (${s.staffId})',
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                    color: AppTheme.textPrimary, fontSize: 12)),
                          ))
                      .toList(),
                  onChanged: (v) => setS(() => selectedStaff = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<BedModel>(
                  isExpanded: true,
                  dropdownColor: AppTheme.bgCard,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'From Bed (optional)'),
                  items: [
                    const DropdownMenuItem<BedModel>(value: null, child: Text('None')),
                    ...allBeds.map((b) => DropdownMenuItem(
                          value: b,
                          child: Text(b.bedCode,
                              style: GoogleFonts.inter(
                                  color: AppTheme.textPrimary, fontSize: 12)),
                        )),
                  ],
                  onChanged: (v) => setS(() => fromBed = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<BedModel>(
                  isExpanded: true,
                  dropdownColor: AppTheme.bgCard,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'To Bed (optional)'),
                  items: [
                    const DropdownMenuItem<BedModel>(value: null, child: Text('None')),
                    ...allBeds.map((b) => DropdownMenuItem(
                          value: b,
                          child: Text(b.bedCode,
                              style: GoogleFonts.inter(
                                  color: AppTheme.textPrimary, fontSize: 12)),
                        )),
                  ],
                  onChanged: (v) => setS(() => toBed = v),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dCtx,
                      initialDate: shiftDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setS(() => shiftDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCardLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            color: AppTheme.textMuted, size: 16),
                        const SizedBox(width: 8),
                        Text(DateFormat('dd MMM yyyy').format(shiftDate),
                            style: GoogleFonts.inter(
                                color: AppTheme.textPrimary, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Reason (optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: Text('Cancel',
                  style: GoogleFonts.inter(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: selectedStaff == null
                  ? null
                  : () async {
                      Navigator.pop(dCtx);
                      try {
                        await _shiftService.logShift(
                          staffId: selectedStaff!.id,
                          fromBedId: fromBed?.id,
                          toBedId: toBed?.id,
                          shiftDate: shiftDate,
                          reason: reasonCtrl.text.trim().isEmpty
                              ? null
                              : reasonCtrl.text.trim(),
                        );
                        _load();
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(minimumSize: Size.zero),
              child: const Text('Log Shift'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showShiftRequestDialog(BuildContext context, AppProvider provider) async {
    final staffRecord = provider.myStaffRecord;
    if (staffRecord == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find your staff record.')),
      );
      return;
    }

    final reasonCtrl = TextEditingController();
    final newRoomCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Request Room Shift',
                style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Your request will be sent to admin for approval',
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 24),

            TextField(
              controller: newRoomCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Requested Room / Bed',
                hintText: 'e.g. Room 106, Sonapur',
                prefixIcon: Icon(Icons.meeting_room_outlined,
                    color: AppTheme.textMuted),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Describe your reason...',
                prefixIcon: Icon(Icons.notes_rounded, color: AppTheme.textMuted),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (reasonCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);

                  final payload = <String, dynamic>{
                    'staff_name': staffRecord['name'],
                    'staff_id': staffRecord['staff_id'],
                    'reason': reasonCtrl.text.trim(),
                  };
                  if (newRoomCtrl.text.isNotEmpty) {
                    payload['requested_room'] = newRoomCtrl.text.trim();
                  }

                  try {
                    await provider.pendingService.submitChange(
                      staffName: staffRecord['name'] as String? ?? 'Staff',
                      changeType: 'shift_request',
                      targetTable: 'staff',
                      targetId: staffRecord['id'] as String?,
                      payload: payload,
                    );
                    await provider.loadPendingChanges();
                    _load();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Room shift request submitted! Waiting for admin approval.'),
                          backgroundColor: AppTheme.success,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'),
                            backgroundColor: AppTheme.danger),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Submit Room Shift'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  final ShiftHistoryModel shift;
  final bool isAdmin;
  final VoidCallback? onDelete;
  const _ShiftCard({required this.shift, required this.isAdmin, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.swap_horiz_rounded,
                color: AppTheme.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shift.staffName ?? 'Unknown Staff',
                    style: GoogleFonts.inter(
                        color: Colors.black87,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(
                  '${shift.fromBedCode ?? "–"} → ${shift.toBedCode ?? "–"}',
                  style: GoogleFonts.inter(
                      color: AppTheme.accent, fontSize: 13),
                ),
                if (shift.reason != null && shift.reason!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(shift.reason!,
                      style: GoogleFonts.inter(
                          color: AppTheme.textSecondary, fontSize: 11)),
                ],
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd MMM yyyy').format(shift.shiftDate),
                  style: GoogleFonts.inter(
                      color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          if (isAdmin && onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.danger, size: 18),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

class _EmptyShifts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.swap_horiz_rounded, color: AppTheme.textMuted, size: 56),
          const SizedBox(height: 16),
          Text('No shift records yet',
              style: GoogleFonts.inter(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Tap + to log a room change',
              style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── My request card (staff view) ───────────────────────────────────────────────
class _MyRequestCard extends StatelessWidget {
  final PendingChange change;
  const _MyRequestCard({required this.change});

  Color get _statusColor {
    switch (change.status) {
      case 'approved': return AppTheme.success;
      case 'rejected': return AppTheme.danger;
      default:         return AppTheme.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 20, right: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: _statusColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.swap_horiz_rounded, color: _statusColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Room Shift Request',
                      style: GoogleFonts.inter(
                          color: _statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(change.status.toUpperCase(),
                      style: GoogleFonts.inter(
                          color: _statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...change.payload.entries
                    .where((e) => e.key != 'staff_id' && e.key != 'staff_name')
                    .map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${_pretty(e.key)}: ',
                                  style: GoogleFonts.inter(
                                      color: AppTheme.textMuted, fontSize: 12)),
                              Expanded(
                                child: Text(e.value.toString(),
                                    style: GoogleFonts.inter(
                                        color: AppTheme.textPrimary,
                                        fontSize: 12)),
                              ),
                            ],
                          ),
                        )),
                if (change.adminNote != null && change.adminNote!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.bgDark,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          change.status == 'approved'
                              ? Icons.check_circle_outline
                              : Icons.info_outline,
                          color: _statusColor, size: 14,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Admin: ${change.adminNote}',
                            style: GoogleFonts.inter(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(_formatDate(change.createdAt),
                    style: GoogleFonts.inter(
                        color: AppTheme.textMuted, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _pretty(String k) =>
      k.replaceAll('_', ' ').split(' ').map((w) =>
          w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 30);
    path.quadraticBezierTo(
        size.width / 4, size.height, size.width / 2, size.height - 15);
    path.quadraticBezierTo(
        size.width * 3 / 4, size.height - 30, size.width, size.height - 5);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
