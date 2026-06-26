// lib/screens/rooms/room_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../models/bed.dart';
import '../../models/staff.dart';
import '../../providers/app_provider.dart';
import '../../services/bed_service.dart';
import '../../services/staff_service.dart';
import '../../services/shift_service.dart';
import '../../widgets/bed_tile.dart';
import '../../widgets/loading_skeleton.dart';

class RoomDetailScreen extends StatefulWidget {
  final String locationId;
  final String roomId;
  const RoomDetailScreen({super.key, required this.locationId, required this.roomId});

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  final _bedService = BedService();
  final _staffService = StaffService();
  bool _loading = true;
  List<BedModel> _beds = [];
  String? _roomCode;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _beds = await _bedService.getByRoom(widget.roomId);
      // Get room code from provider rooms list
      final rooms = context.read<AppProvider>().rooms;
      final room = rooms.where((r) => r.id == widget.roomId).firstOrNull;
      _roomCode = room?.roomCode;
    } catch (e) {
      debugPrint('Error loading beds: $e');
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isAdmin = provider.isAdmin;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.go('/rooms/${widget.locationId}'),
          color: AppTheme.textSecondary,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_roomCode ?? 'Room Detail',
                style: GoogleFonts.inter(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
            Text('${_beds.length} beds · ${_beds.where((b) => b.isOccupied).length} occupied',
                style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined, color: AppTheme.primary),
            tooltip: 'Add Bed',
            onPressed: () => _showAddBedDialog(context),
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
              child: _beds.isEmpty
                  ? _EmptyBeds(onAdd: () => _showAddBedDialog(context))
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: _beds.length,
                      itemBuilder: (ctx, i) => BedTile(
                        bed: _beds[i],
                        onTap: () => _showBedActions(context, _beds[i], isAdmin),
                      ),
                    ),
            ),
    );
  }

  void _showBedActions(BuildContext ctx, BedModel bed, bool isAdmin) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bCtx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(bed.bedCode,
                    style: GoogleFonts.inter(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.bedStatusColor(bed.status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(bed.status,
                      style: GoogleFonts.inter(
                          color: AppTheme.bedStatusColor(bed.status),
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            if (bed.occupant != null) ...[
              const SizedBox(height: 8),
              Text(
                  '${bed.occupant!.name} (${bed.occupant!.staffId})',
                  style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            const Divider(color: AppTheme.divider),
            const SizedBox(height: 8),

            // Assign staff (viewer + admin can assign)
            if (bed.isVacant)
              _ActionTile(
                icon: Icons.person_add_rounded,
                label: 'Assign Staff',
                color: AppTheme.primary,
                onTap: () {
                  Navigator.pop(bCtx);
                  _showAssignDialog(ctx, bed);
                },
              ),

            // Mark on vacation (admin only)
            if (isAdmin && bed.occupant != null && bed.status == 'FULL')
              _ActionTile(
                icon: Icons.flight_takeoff_rounded,
                label: 'Mark On Vacation',
                color: AppTheme.vacation,
                onTap: () async {
                  Navigator.pop(bCtx);
                  await _bedService.updateStatus(bed.id, 'VACATION');
                  await _staffService.markOnLeave(bed.occupant!.id);
                  await _load();
                },
              ),

            // Mark returned (admin only)
            if (isAdmin && bed.status == 'VACATION')
              _ActionTile(
                icon: Icons.flight_land_rounded,
                label: 'Mark Returned',
                color: AppTheme.success,
                onTap: () async {
                  Navigator.pop(bCtx);
                  await _bedService.updateStatus(bed.id, 'FULL');
                  if (bed.occupant != null) {
                    await _staffService.markReturned(bed.occupant!.id);
                  }
                  await _load();
                },
              ),

            // Remove staff (admin only)
            if (isAdmin && bed.isOccupied)
              _ActionTile(
                icon: Icons.person_remove_rounded,
                label: 'Remove Staff',
                color: AppTheme.danger,
                onTap: () async {
                  Navigator.pop(bCtx);
                  await _bedService.removeStaff(bed.id);
                  await _load();
                },
              ),

            // Delete bed (admin only)
            if (isAdmin && !bed.isOccupied)
              _ActionTile(
                icon: Icons.delete_outline,
                label: 'Delete Bed',
                color: AppTheme.danger,
                onTap: () async {
                  Navigator.pop(bCtx);
                  await _bedService.delete(bed.id);
                  await _load();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showAssignDialog(BuildContext ctx, BedModel bed) async {
    final unassigned = await _staffService.getUnassigned();
    if (unassigned.isEmpty) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
            content: Text('No unassigned active staff available')));
      }
      return;
    }

    StaffModel? selected;
    String statusToSet = 'FULL';

    if (!ctx.mounted) return;
    showDialog(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setS) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Assign Staff to ${bed.bedCode}',
              style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<StaffModel>(
                dropdownColor: AppTheme.bgCard,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Select Staff'),
                items: unassigned
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text('${s.name} (${s.staffId})',
                              style: GoogleFonts.inter(
                                  color: AppTheme.textPrimary, fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (v) => setS(() => selected = v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: statusToSet,
                dropdownColor: AppTheme.bgCard,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'FULL', child: Text('FULL')),
                  DropdownMenuItem(value: 'VACATION', child: Text('VACATION')),
                ],
                onChanged: (v) => setS(() => statusToSet = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: selected == null
                  ? null
                  : () async {
                      Navigator.pop(dCtx);
                      try {
                        final oldBedId = bed.id;
                        await _bedService.assignStaff(
                          bedId: bed.id,
                          staffId: selected!.id,
                          bedStatus: statusToSet,
                        );
                        // Log shift
                        await ShiftService().logShift(
                          staffId: selected!.id,
                          fromBedId: null,
                          toBedId: oldBedId,
                          shiftDate: DateTime.now(),
                          reason: 'Initial assignment',
                        );
                        if (statusToSet == 'VACATION') {
                          await _staffService.update(selected!.id, {'status': 'On Leave'});
                        }
                        await _load();
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(minimumSize: Size.zero),
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddBedDialog(BuildContext ctx) {
    int bedNumber = _beds.isNotEmpty ? (_beds.map((b) => b.bedNumber).reduce((a, b) => a > b ? a : b) + 1) : 1;
    String position = 'LB';

    showDialog(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setS) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Add Bed', style: GoogleFonts.inter(color: AppTheme.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: bedNumber.toString(),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Bed Number'),
                onChanged: (v) => bedNumber = int.tryParse(v) ?? bedNumber,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: position,
                dropdownColor: AppTheme.bgCard,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Position'),
                items: kBedPositions
                    .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(kBedPositionLabels[p] ?? p,
                              style: GoogleFonts.inter(color: AppTheme.textPrimary)),
                        ))
                    .toList(),
                onChanged: (v) => setS(() => position = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dCtx);
                final bedCode = '${_roomCode ?? widget.roomId}-BD$bedNumber-$position';
                try {
                  await _bedService.create(BedModel(
                    id: '',
                    bedCode: bedCode,
                    roomId: widget.roomId,
                    bedNumber: bedNumber,
                    position: position,
                    status: 'VACANT',
                  ));
                  await _load();
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              style: ElevatedButton.styleFrom(minimumSize: Size.zero),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(label,
          style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 14)),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}

class _EmptyBeds extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyBeds({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bed_outlined, color: AppTheme.textMuted, size: 56),
          const SizedBox(height: 16),
          Text('No beds in this room',
              style: GoogleFonts.inter(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Tap the + icon to add beds',
              style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}
