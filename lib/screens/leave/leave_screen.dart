// lib/screens/leave/leave_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/staff.dart';
import '../../providers/app_provider.dart';
import '../../services/staff_service.dart';
import '../../services/pending_service.dart';
import '../../widgets/loading_skeleton.dart';

class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key});
  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen>
    with SingleTickerProviderStateMixin {
  final _staffService = StaffService();
  bool _loading = true;
  List<StaffModel> _onLeave = [];
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
    _onLeave = await _staffService.getOnLeave();
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
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Text('Leave Management',
            style: GoogleFonts.inter(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.vacation.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_onLeave.length} on leave',
              style: GoogleFonts.inter(
                  color: AppTheme.vacation,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
        bottom: isStaff
            ? TabBar(
                controller: _tabs,
                indicatorColor: AppTheme.primary,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textMuted,
                tabs: const [
                  Tab(text: 'Staff on Leave'),
                  Tab(text: 'My Requests'),
                ],
              )
            : null,
      ),
      // Staff: show FAB to request leave
      floatingActionButton: isStaff
          ? FloatingActionButton.extended(
              onPressed: () => _showLeaveRequestDialog(context, provider),
              backgroundColor: AppTheme.vacation,
              icon: const Icon(Icons.flight_takeoff_rounded, color: Colors.white),
              label: Text('Request Leave',
                  style: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Column(children: [SkeletonCard(), SkeletonCard()]),
            )
          : isStaff
              ? TabBarView(
                  controller: _tabs,
                  children: [
                    _buildLeaveList(isAdmin),
                    _buildMyRequests(provider),
                  ],
                )
              : _buildLeaveList(isAdmin),
    );
  }

  Widget _buildLeaveList(bool isAdmin) {
    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: AppTheme.bgCard,
      onRefresh: _load,
      child: _onLeave.isEmpty
          ? _EmptyLeave()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: _onLeave.length,
              itemBuilder: (ctx, i) => _LeaveCard(
                staff: _onLeave[i],
                isAdmin: isAdmin,
                onMarkReturned: isAdmin
                    ? () async {
                        await _staffService.markReturned(_onLeave[i].id);
                        _load();
                      }
                    : null,
              ),
            ),
    );
  }

  Widget _buildMyRequests(AppProvider provider) {
    final leaveReqs = _myPending
        .where((c) => c.changeType == 'leave_request' || c.changeType == 'shift_request')
        .toList();

    if (leaveReqs.isEmpty) {
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
            Text('Tap the button below to request leave or a room shift',
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: leaveReqs.length,
      itemBuilder: (ctx, i) => _MyRequestCard(change: leaveReqs[i]),
    );
  }

  Future<void> _showLeaveRequestDialog(
      BuildContext context, AppProvider provider) async {
    final staffRecord = provider.myStaffRecord;
    if (staffRecord == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find your staff record.')),
      );
      return;
    }

    final reasonCtrl = TextEditingController();
    final fromCtrl = TextEditingController();
    final toCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
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
              Text('Submit Request',
                  style: GoogleFonts.inter(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Your request will be sent to admin for approval',
                  style: GoogleFonts.inter(
                      color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 24),

              _buildDateRow(ctx, 'From Date', fromCtrl),
              const SizedBox(height: 12),
              _buildDateRow(ctx, 'To Date', toCtrl),
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
                    if (fromCtrl.text.isNotEmpty) payload['from_date'] = fromCtrl.text;
                    if (toCtrl.text.isNotEmpty) payload['to_date'] = toCtrl.text;

                    try {
                      await provider.pendingService.submitChange(
                        staffName: staffRecord['name'] as String? ?? 'Staff',
                        changeType: 'leave_request',
                        targetTable: 'staff',
                        targetId: staffRecord['id'] as String?,
                        payload: payload,
                      );
                      await provider.loadPendingChanges();
                      _load();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Leave request submitted! Waiting for admin approval.'),
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
                  icon: const Icon(Icons.flight_takeoff_rounded),
                  label: const Text('Submit Leave Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.vacation,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateRow(BuildContext context, String label, TextEditingController ctrl) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppTheme.primary,
                surface: AppTheme.bgCard,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) {
          ctrl.text =
              '${picked.day}/${picked.month}/${picked.year}';
          setState(() {});
        }
      },
      child: AbsorbPointer(
        child: TextField(
          controller: ctrl,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.calendar_today_outlined,
                color: AppTheme.textMuted),
            hintText: 'Select date',
          ),
        ),
      ),
    );
  }
}

// ── Type chip ─────────────────────────────────────────────────────────────────
class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _TypeChip({
    required this.label, required this.icon, required this.selected,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : AppTheme.bgDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : AppTheme.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : AppTheme.textMuted, size: 22),
            const SizedBox(height: 6),
            Text(label,
                style: GoogleFonts.inter(
                    color: selected ? color : AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ],
        ),
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

  String get _typeLabel => change.changeType == 'leave_request'
      ? 'Leave Request'
      : 'Room Shift Request';

  IconData get _typeIcon => change.changeType == 'leave_request'
      ? Icons.flight_takeoff_rounded
      : Icons.swap_horiz_rounded;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
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
                Icon(_typeIcon, color: _statusColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_typeLabel,
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

// ── Leave card (admin view) ─────────────────────────────────────────────────
class _LeaveCard extends StatelessWidget {
  final StaffModel staff;
  final bool isAdmin;
  final VoidCallback? onMarkReturned;
  const _LeaveCard({required this.staff, required this.isAdmin, this.onMarkReturned});

  @override
  Widget build(BuildContext context) {
    final initials =
        staff.name.split(' ').take(2).map((w) => w[0]).join().toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.vacation.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppTheme.vacation.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(initials,
                  style: GoogleFonts.inter(
                      color: AppTheme.vacation,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(staff.name,
                    style: GoogleFonts.inter(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('ID: ${staff.staffId}',
                    style: GoogleFonts.inter(
                        color: AppTheme.textMuted, fontSize: 11)),
                if (staff.nationality != null)
                  Text(staff.nationality!,
                      style: GoogleFonts.inter(
                          color: AppTheme.textMuted, fontSize: 11)),
              ],
            ),
          ),
          if (isAdmin && onMarkReturned != null)
            ElevatedButton.icon(
              onPressed: onMarkReturned,
              icon: const Icon(Icons.flight_land_rounded, size: 14),
              label: const Text('Returned', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                minimumSize: const Size(80, 32),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyLeave extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.beach_access_rounded,
              color: AppTheme.textMuted, size: 56),
          const SizedBox(height: 16),
          Text('No staff on leave',
              style: GoogleFonts.inter(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('All staff are currently active',
              style: GoogleFonts.inter(
                  color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}
