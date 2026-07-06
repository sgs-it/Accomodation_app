import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

class OnLeaveStaffScreen extends StatefulWidget {
  const OnLeaveStaffScreen({super.key});

  @override
  State<OnLeaveStaffScreen> createState() => _OnLeaveStaffScreenState();
}

class _OnLeaveStaffScreenState extends State<OnLeaveStaffScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _onLeaveStaff = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final client = Supabase.instance.client;

    try {
      // Fetch all On Leave staff
      final staffData = await client
          .from('staff')
          .select()
          .eq('status', 'On Leave')
          .order('name', ascending: true);

      // Fetch approved leave requests to get leave dates
      List<dynamic> changesData = [];
      try {
        changesData = await client
            .from('pending_changes')
            .select()
            .eq('change_type', 'leave_request')
            .eq('status', 'approved');
      } catch (e) {
        debugPrint('Error fetching leave changes: $e');
      }

      final List<Map<String, dynamic>> result = [];
      for (final staff in (staffData as List)) {
        String fromDate = '';
        String toDate = '';
        String leaveType = 'Annual leave';

        // Find most recent approved leave for this staff
        final leaves = changesData
            .where((c) => c['target_id'] == staff['id'])
            .toList();

        if (leaves.isNotEmpty) {
          leaves.sort((a, b) {
            final dA = DateTime.parse(a['created_at'].toString());
            final dB = DateTime.parse(b['created_at'].toString());
            return dB.compareTo(dA);
          });
          final latest = leaves.first;
          final payload = latest['payload'];
          if (payload is Map) {
            fromDate = payload['from_date']?.toString() ?? '';
            toDate = payload['to_date']?.toString() ?? '';
            leaveType = payload['leave_type']?.toString() ?? 'Annual leave';
          }
        }

        result.add({
          'staff': Map<String, dynamic>.from(staff),
          'fromDate': fromDate,
          'toDate': toDate,
          'leaveType': leaveType,
        });
      }

      if (mounted) {
        setState(() => _onLeaveStaff = result);
      }
    } catch (e) {
      debugPrint('Error loading on leave staff: $e');
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppTheme.warning,
        title: Text('Staff On Leave (${_onLeaveStaff.length})',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.warning))
          : _onLeaveStaff.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.event_busy, color: AppTheme.textMuted, size: 56),
                      const SizedBox(height: 16),
                      Text('No Staff On Leave',
                          style: GoogleFonts.inter(
                              color: const Color(0xFF1E293B), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text('Staff currently on leave will appear here.',
                          style: GoogleFonts.inter(color: AppTheme.textSecondary)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppTheme.warning,
                  backgroundColor: Colors.white,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _onLeaveStaff.length,
                    itemBuilder: (ctx, i) {
                      final item = _onLeaveStaff[i];
                      final staff = item['staff'] as Map<String, dynamic>;
                      final fromDate = item['fromDate'] as String;
                      final toDate = item['toDate'] as String;
                      final leaveType = item['leaveType'] as String;
                      final isAnnual = leaveType == 'Annual leave';

                      return GestureDetector(
                        onTap: () => context.push('/staff/${staff['id']}'),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppTheme.warning.withValues(alpha: 0.2)),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.warning.withValues(alpha: 0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.warning.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isAnnual
                                      ? Icons.flight_takeoff_rounded
                                      : Icons.medical_services_outlined,
                                  color: AppTheme.warning,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(staff['name'] ?? 'Unknown',
                                        style: GoogleFonts.inter(
                                            color: Colors.black87,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold)),
                                    Text('ID: ${staff['staff_id']}',
                                        style: GoogleFonts.inter(
                                            color: AppTheme.textMuted, fontSize: 12)),
                                    const SizedBox(height: 6),
                                    // Leave type badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isAnnual
                                            ? AppTheme.warning.withValues(alpha: 0.12)
                                            : AppTheme.danger.withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(leaveType,
                                          style: GoogleFonts.inter(
                                              color: isAnnual
                                                  ? AppTheme.warning
                                                  : AppTheme.danger,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                    if (fromDate.isNotEmpty || toDate.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.date_range,
                                              size: 13, color: AppTheme.textMuted),
                                          const SizedBox(width: 4),
                                          Text(
                                            fromDate.isNotEmpty && toDate.isNotEmpty
                                                ? '$fromDate → $toDate'
                                                : fromDate.isNotEmpty
                                                    ? 'From: $fromDate'
                                                    : 'Until: $toDate',
                                            style: GoogleFonts.inter(
                                                color: AppTheme.textMuted,
                                                fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios,
                                  size: 16, color: AppTheme.textMuted),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
