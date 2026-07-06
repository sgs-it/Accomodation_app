import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';
import '../../services/bed_service.dart';
import '../../services/staff_service.dart';
import '../../services/shift_service.dart';
import '../../services/auth_service.dart';
import '../../models/bed.dart';

class UnassignedStaffScreen extends StatefulWidget {
  const UnassignedStaffScreen({super.key});

  @override
  State<UnassignedStaffScreen> createState() => _UnassignedStaffScreenState();
}

class _UnassignedStaffScreenState extends State<UnassignedStaffScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _unassignedStaff = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? _error;

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final client = Supabase.instance.client;

    try {
      // Step 1: Get all staff with status 'On Leave'
      final staffList = await client
          .from('staff')
          .select('id, name, staff_id, status')
          .eq('status', 'On Leave')
          .order('name', ascending: true);

      debugPrint('[Unassigned] On Leave staff count: ${staffList.length}');

      if (staffList.isEmpty) {
        if (mounted) setState(() { _unassignedStaff = []; _loading = false; });
        return;
      }

      // Step 2: Get all current bed assignments for those staff
      final staffIds = staffList.map((s) => s['id'] as String).toList();
      final assignments = await client
          .from('bed_assignments')
          .select('staff_id')
          .inFilter('staff_id', staffIds);

      final assignedIds = assignments
          .map((a) => a['staff_id'] as String)
          .toSet();

      debugPrint('[Unassigned] Assigned IDs: $assignedIds');

      // Step 3: Keep only those with NO bed assignment
      final unassigned = staffList
          .where((s) => !assignedIds.contains(s['id'] as String))
          .toList();

      debugPrint('[Unassigned] Truly unassigned count: ${unassigned.length}');

      // Step 4: Enrich with return date from approved leave requests
      List<dynamic> changesData = [];
      try {
        changesData = await client
            .from('pending_changes')
            .select('target_id, payload, created_at')
            .eq('change_type', 'leave_request')
            .eq('status', 'approved')
            .inFilter('target_id', staffIds);
      } catch (e) {
        debugPrint('[Unassigned] Could not fetch leave dates: $e');
      }

      final List<Map<String, dynamic>> result = [];
      for (final staff in unassigned) {
        String returnDate = '';
        try {
          final leaves = changesData
              .where((c) {
                if (c['target_id'] != staff['id']) return false;
                final p = c['payload'];
                return p is Map && p['leave_type'] == 'Annual leave';
              })
              .toList();

          if (leaves.isNotEmpty) {
            leaves.sort((a, b) =>
                DateTime.parse(b['created_at'].toString())
                    .compareTo(DateTime.parse(a['created_at'].toString())));
            final p = leaves.first['payload'];
            if (p is Map) returnDate = p['to_date']?.toString() ?? '';
          }
        } catch (_) {}

        result.add({
          'staff': Map<String, dynamic>.from(staff),
          'returnDate': returnDate,
        });
      }

      if (mounted) setState(() { _unassignedStaff = result; });
    } catch (e, st) {
      debugPrint('[Unassigned] Fatal error: $e\n$st');
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAssignBedDialog(BuildContext ctx, Map<String, dynamic> staff) async {
    final bedService = BedService();
    final beds = await bedService.getVacantBeds();
    
    if (beds.isEmpty) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
            content: Text('No vacant beds available')));
      }
      return;
    }

    BedModel? selectedBed;
    
    if (!ctx.mounted) return;
    showDialog(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setS) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Assign Bed for ${staff['name']}',
              style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 15)),
          content: DropdownButtonFormField<BedModel>(
            isExpanded: true,
            dropdownColor: AppTheme.bgCard,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(labelText: 'Select Vacant Bed'),
            items: beds
                .map((b) => DropdownMenuItem(
                      value: b,
                      child: Text(b.bedCode,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              color: AppTheme.textPrimary, fontSize: 13)),
                    ))
                .toList(),
            onChanged: (v) => setS(() => selectedBed = v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: selectedBed == null
                  ? null
                  : () async {
                      Navigator.pop(dCtx);
                      setState(() => _loading = true);
                      try {
                        await bedService.assignStaff(
                          bedId: selectedBed!.id,
                          staffId: staff['id'],
                          bedStatus: 'FULL',
                        );
                        await StaffService().update(staff['id'], {'status': 'Active'});
                        await ShiftService().logShift(
                          staffId: staff['id'],
                          fromBedId: null,
                          toBedId: selectedBed!.id,
                          shiftDate: DateTime.now(),
                          reason: 'Assigned from Unassigned Staff',
                        );
                        
                        try {
                          await AuthService().updatePassword(staff['id'], selectedBed!.bedCode);
                        } catch (e) {
                          debugPrint('Failed to update password: $e');
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Bed assigned, but password update failed: $e')));
                          }
                        }
                        
                        await _load();
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Error: $e')));
                          setState(() => _loading = false);
                        }
                      }
                    },
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B5CF6),
        title: Text('Unassigned Staff',
            style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.danger, size: 56),
              const SizedBox(height: 16),
              Text('Failed to load staff',
                  style: GoogleFonts.inter(
                      color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    if (_unassignedStaff.isEmpty) {
      return RefreshIndicator(
        color: AppTheme.primary,
        backgroundColor: Colors.white,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.beach_access_outlined, color: Colors.black38, size: 56),
                    const SizedBox(height: 16),
                    Text('No Unassigned Staff',
                        style: GoogleFonts.inter(
                            color: Colors.black87, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('Staff on Annual Leave will appear here.',
                        style: GoogleFonts.inter(color: Colors.black54)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isAdmin = context.watch<AppProvider>().isAdmin;

    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: Colors.white,
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _unassignedStaff.length,
        itemBuilder: (ctx, i) {
          final item = _unassignedStaff[i];
          final staff = item['staff'] as Map<String, dynamic>;
          final returnDate = item['returnDate'] as String;

          return GestureDetector(
            onTap: () => context.push('/staff/${staff['id']}'),
            child: Container(
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
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(staff['name'] ?? 'Unknown',
                            style: GoogleFonts.inter(
                                color: Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        Text('ID: ${staff['staff_id']}',
                            style: GoogleFonts.inter(
                                color: AppTheme.textMuted, fontSize: 13)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.event, size: 14, color: AppTheme.warning),
                            const SizedBox(width: 4),
                            Text('Returns: $returnDate',
                                style: GoogleFonts.inter(
                                    color: AppTheme.warning,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isAdmin)
                    ElevatedButton(
                      onPressed: () => _showAssignBedDialog(context, staff),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        minimumSize: const Size(0, 36), // Fixes double.infinity width crash
                      ),
                      child: Text('Assign', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  if (!isAdmin)
                    const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.textMuted),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
