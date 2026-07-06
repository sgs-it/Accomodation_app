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
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(children: [Column(
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
                          'Leave Management',
                          style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_onLeave.length} on leave',
                          style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
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
                    Tab(text: 'Staff on Leave'),
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
                            _buildLeaveList(isAdmin),
                            _buildMyRequests(provider),
                          ],
                        )
                      : _buildLeaveList(isAdmin),
            ),
          ),
        ],
      ),
      
          if (isStaff)
            Positioned(
              right: 16,
              bottom: 110,
              child: FloatingActionButton.extended(
                onPressed: () => _showLeaveRequestDialog(context, provider),
                backgroundColor: AppTheme.vacation,
                icon: const Icon(Icons.flight_takeoff_rounded, color: Colors.white),
                label: Text('Request Leave',
                    style: GoogleFonts.inter(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),

    );
  }

  Widget _buildLeaveList(bool isAdmin) {
    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: Colors.white,
      onRefresh: _load,
      child: _onLeave.isEmpty
          ? _EmptyLeave()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
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

    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppTheme.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _LeaveRequestSheet(
        provider: provider,
        staffRecord: staffRecord,
        onComplete: () {
          _load();
        },
      ),
    );
  }
}

class _LeaveRequestSheet extends StatefulWidget {
  final AppProvider provider;
  final Map<String, dynamic> staffRecord;
  final VoidCallback onComplete;

  const _LeaveRequestSheet({
    required this.provider,
    required this.staffRecord,
    required this.onComplete,
  });

  @override
  State<_LeaveRequestSheet> createState() => _LeaveRequestSheetState();
}

class _LeaveRequestSheetState extends State<_LeaveRequestSheet> {
  final _reasonCtrl = TextEditingController();
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;

  String _leaveType = 'Sick Leave';
  final List<String> _leaveTypes = [
    'Sick Leave',
    'Annual leave',
    'Personal leave',
    'Emergency Leave'
  ];
  bool _hasSupportingDocs = false;

  int _pastSickLeaveCount = 0;
  int _pastAnnualLeaveDays = 0;

  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchPastLeaves();
  }

  Future<void> _fetchPastLeaves() async {
    try {
      final pastLeaves = await widget.provider.pendingService
          .getApprovedLeavesForStaff(widget.staffRecord['id'] as String);
      
      final now = DateTime.now();
      final twoYearsAgo = now.subtract(const Duration(days: 365 * 2));
      
      for (var leave in pastLeaves) {
        final type = leave.payload['leave_type'];
        if (type == 'Sick Leave' && leave.createdAt.year == now.year) {
          _pastSickLeaveCount++;
        } else if (type == 'Annual leave' && leave.createdAt.isAfter(twoYearsAgo)) {
          _pastAnnualLeaveDays += (leave.payload['duration_days'] as num?)?.toInt() ?? 0;
        }
      }
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  int get _requestedDuration {
    if (_fromDate == null || _toDate == null) return 0;
    // +1 to include both start and end days
    return _toDate!.difference(_fromDate!).inDays + 1;
  }

  void _submit() async {
    if (_reasonCtrl.text.trim().isEmpty) {
      _showError('Please provide a reason.');
      return;
    }
    if (_fromDate == null || _toDate == null) {
      _showError('Please select From and To dates.');
      return;
    }
    if (_toDate!.isBefore(_fromDate!)) {
      _showError('To Date cannot be before From Date.');
      return;
    }

    final duration = _requestedDuration;

    // Validate based on leave type rules
    if (_leaveType == 'Emergency Leave') {
      if (duration < 1 || duration > 10) {
        _showError('Emergency Leave must be between 1 and 10 days.');
        return;
      }
    } else if (_leaveType == 'Annual leave') {
      if (duration < 7) {
        _showError('Annual leave must be at least 7 days.');
        return;
      }
      if (_pastAnnualLeaveDays + duration > 60) {
        _showError('You cannot exceed 60 days of Annual leave per 2 years. You have already taken $_pastAnnualLeaveDays days.');
        return;
      }
    }

    Navigator.pop(context); // Close sheet

    final payload = <String, dynamic>{
      'staff_name': widget.staffRecord['name'],
      'staff_id': widget.staffRecord['staff_id'],
      'reason': _reasonCtrl.text.trim(),
      'leave_type': _leaveType,
      'duration_days': duration,
      'from_date': _fromCtrl.text,
      'to_date': _toCtrl.text,
    };

    if (_leaveType == 'Sick Leave') {
      payload['supporting_docs_provided'] = _hasSupportingDocs;
      payload['past_sick_leaves_this_year'] = _pastSickLeaveCount;
    }

    try {
      await widget.provider.pendingService.submitChange(
        staffName: widget.staffRecord['name'] as String? ?? 'Staff',
        changeType: 'leave_request',
        targetTable: 'staff',
        targetId: widget.staffRecord['id'] as String?,
        payload: payload,
      );
      await widget.provider.loadPendingChanges();
      widget.onComplete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave request submitted! Waiting for admin approval.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Error: $e');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.danger),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Center(child: CircularProgressIndicator(color: AppTheme.primary)),
          ],
        ),
      );
    }
    
    if (_error.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.danger, size: 48),
            const SizedBox(height: 16),
            Text('Error loading history: $_error', style: const TextStyle(color: AppTheme.danger)),
          ],
        ),
      );
    }

    final bool showSalaryWarning = _leaveType == 'Sick Leave' && (_pastSickLeaveCount + 1) > 12;

    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
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
          Text('Request Leave',
              style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Your request will be sent to admin for approval',
              style: GoogleFonts.inter(
                  color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 24),

          // Leave Type Dropdown
          Text('Leave Type', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.divider),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _leaveType,
                isExpanded: true,
                dropdownColor: AppTheme.bgCard,
                icon: const Icon(Icons.arrow_drop_down, color: AppTheme.textPrimary),
                style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 14),
                items: _leaveTypes.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _leaveType = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Date Rows
          Row(
            children: [
              Expanded(child: _buildDateRow('From Date', _fromCtrl, true)),
              const SizedBox(width: 12),
              Expanded(child: _buildDateRow('To Date', _toCtrl, false)),
            ],
          ),
          
          if (_fromDate != null && _toDate != null && _requestedDuration > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Duration: $_requestedDuration day(s)',
                style: GoogleFonts.inter(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),

          const SizedBox(height: 16),

          // Sick Leave specific fields
          if (_leaveType == 'Sick Leave') ...[
            if (showSalaryWarning)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sick leave finished and salary will be deducted.',
                        style: GoogleFonts.inter(color: AppTheme.danger, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.bgDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Supporting documents have?', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
                      Switch(
                        value: _hasSupportingDocs,
                        onChanged: (v) => setState(() => _hasSupportingDocs = v),
                        activeColor: AppTheme.primary,
                      ),
                    ],
                  ),
                  Text('The supporting document can be submitted Directly.', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          TextField(
            controller: _reasonCtrl,
            maxLines: 2,
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
              onPressed: _submit,
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
  );
}

  Widget _buildDateRow(String label, TextEditingController ctrl, bool isFrom) {
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
          ctrl.text = '${picked.day}/${picked.month}/${picked.year}';
          setState(() {
            if (isFrom) _fromDate = picked;
            else _toDate = picked;
          });
        }
      },
      child: AbsorbPointer(
        child: TextField(
          controller: ctrl,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.calendar_today_outlined, color: AppTheme.textMuted),
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
                                        color: const Color(0xFF1E293B),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500)),
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
    String getInitials(String name) {
      if (name.trim().isEmpty) return '?';
      final parts = name.trim().split(' ').where((w) => w.isNotEmpty).take(2);
      if (parts.isEmpty) return '?';
      return parts.map((w) => w[0].toUpperCase()).join();
    }
    final initials = getInitials(staff.name);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.vacation.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.vacation.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppTheme.vacation.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(initials,
                  style: GoogleFonts.inter(
                      color: AppTheme.vacation,
                      fontSize: 16,
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
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('ID: ${staff.staffId}',
                    style: GoogleFonts.inter(
                        color: AppTheme.textMuted, fontSize: 13)),
                if (staff.nationality != null)
                  Text(staff.nationality!,
                      style: GoogleFonts.inter(
                          color: AppTheme.textMuted, fontSize: 13)),
              ],
            ),
          ),
          if (isAdmin && onMarkReturned != null)
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.success.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: onMarkReturned,
                icon: const Icon(Icons.flight_land_rounded, size: 16, color: Colors.white),
                label: const Text('Returned', style: TextStyle(fontSize: 12, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
        ],
      ),
    );
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
