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
import '../../widgets/loading_skeleton.dart';

class ShiftHistoryScreen extends StatefulWidget {
  const ShiftHistoryScreen({super.key});

  @override
  State<ShiftHistoryScreen> createState() => _ShiftHistoryScreenState();
}

class _ShiftHistoryScreenState extends State<ShiftHistoryScreen> {
  final _shiftService = ShiftService();
  bool _loading = true;
  List<ShiftHistoryModel> _shifts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _shifts = await _shiftService.getAll();
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isAdmin = provider.isAdmin;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Text('Room Shift Log',
            style: GoogleFonts.inter(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.primary),
            tooltip: 'Log Shift',
            onPressed: () => _showLogShiftDialog(context),
          ),
        ],
      ),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Column(children: [SkeletonCard(), SkeletonCard(), SkeletonCard()]),
            )
          : RefreshIndicator(
              color: AppTheme.primary,
              backgroundColor: AppTheme.bgCard,
              onRefresh: _load,
              child: _shifts.isEmpty
                  ? _EmptyShifts()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
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
            ),
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
                  dropdownColor: AppTheme.bgCard,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Staff Member'),
                  items: allStaff
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text('${s.name} (${s.staffId})',
                                style: GoogleFonts.inter(
                                    color: AppTheme.textPrimary, fontSize: 12)),
                          ))
                      .toList(),
                  onChanged: (v) => setS(() => selectedStaff = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<BedModel>(
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
}

class _ShiftCard extends StatelessWidget {
  final ShiftHistoryModel shift;
  final bool isAdmin;
  final VoidCallback? onDelete;
  const _ShiftCard({required this.shift, required this.isAdmin, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
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
                        color: AppTheme.textPrimary,
                        fontSize: 14,
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
