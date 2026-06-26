// lib/screens/leave/leave_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/staff.dart';
import '../../providers/app_provider.dart';
import '../../services/staff_service.dart';
import '../../widgets/loading_skeleton.dart';

class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  final _staffService = StaffService();
  bool _loading = true;
  List<StaffModel> _onLeave = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _onLeave = await _staffService.getOnLeave();
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isAdmin = provider.isAdmin;

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
              color: AppTheme.vacation.withOpacity(0.15),
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
      ),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Column(children: [SkeletonCard(), SkeletonCard()]),
            )
          : RefreshIndicator(
              color: AppTheme.primary,
              backgroundColor: AppTheme.bgCard,
              onRefresh: _load,
              child: _onLeave.isEmpty
                  ? _EmptyLeave()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
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
            ),
    );
  }
}

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
        border: Border.all(color: AppTheme.vacation.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.vacation.withOpacity(0.15),
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
                    style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
                if (staff.nationality != null)
                  Text(staff.nationality!,
                      style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11)),
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
              style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}
