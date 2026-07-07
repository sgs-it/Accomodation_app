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
import '../../services/auth_service.dart';
import '../../widgets/bed_tile.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/stat_card.dart';

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
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        color: AppTheme.primary,
        backgroundColor: Colors.white,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  // Purple Header
                  ClipPath(
                    clipper: _HeaderClipper(),
                    child: Container(
                      height: 280,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF4C1D95)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => context.go('/rooms/${widget.locationId}'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_roomCode ?? 'Room Detail',
                                        style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text('${_beds.length} beds · ${_beds.where((b) => b.isVacant).length} vacant',
                                        style: GoogleFonts.inter(
                                            color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                                  ],
                                ),
                              ),
                              if (isAdmin)
                                Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.add_box, color: Color(0xFF4C1D95)),
                                    onPressed: () => _showAddBedDialog(context),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Overlapping content
                  Container(
                    margin: const EdgeInsets.only(top: 125),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Summary stats row
                        if (!_loading)
                          Row(
                            children: [
                              Expanded(
                                child: _RoomStatChip(
                                  label: 'Total Beds',
                                  value: _beds.length,
                                  icon: Icons.bed,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _RoomStatChip(
                                  label: 'Vacant Beds',
                                  value: _beds.where((b) => b.isVacant).length,
                                  icon: Icons.single_bed,
                                  color: AppTheme.success,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _RoomStatChip(
                                  label: 'Occupied Beds',
                                  value: _beds.where((b) => b.isOccupied).length,
                                  icon: Icons.person,
                                  color: AppTheme.warning,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 24),
                        // Beds List
                        if (_loading)
                          const Column(children: [SkeletonCard(), SkeletonCard()])
                        else if (_beds.isEmpty)
                          _EmptyBeds(onAdd: () => _showAddBedDialog(context))
                        else
                          _buildContent(context, isAdmin),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isAdmin) {
    final vacantBeds = _beds.where((b) => b.isVacant).toList();
    final occupiedBeds = _beds.where((b) => b.isOccupied).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Staff List
        Text('Staff in Room',
            style: GoogleFonts.inter(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (occupiedBeds.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text('No staff assigned', style: GoogleFonts.inter(color: AppTheme.textMuted)),
          )
        else
          ...occupiedBeds.map((bed) => _StaffListTile(
                bed: bed,
                isAdmin: isAdmin,
                onTap: () => _showBedActions(context, bed, isAdmin),
                onEdit: () => _showEditBedDialog(context, bed),
              )),

        if (occupiedBeds.isNotEmpty) const SizedBox(height: 24),

        // Vacant Beds
        Text('Vacant Beds',
            style: GoogleFonts.inter(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (vacantBeds.isEmpty)
          Text('No vacant beds', style: GoogleFonts.inter(color: AppTheme.textMuted))
        else
          ...vacantBeds.map((bed) => _VacantBedTile(
                bed: bed,
                isAdmin: isAdmin,
                onTap: () => _showBedActions(context, bed, isAdmin),
                onEdit: () => _showEditBedDialog(context, bed),
              )),
      ],
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
                isExpanded: true,
                dropdownColor: AppTheme.bgCard,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Select Staff'),
                items: unassigned
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text('${s.name} (${s.staffId})',
                              overflow: TextOverflow.ellipsis,
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
                        
                        // Update password to new bed ID
                        try {
                          await AuthService().updatePassword(selected!.id, bed.bedCode);
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
                final bedCode = '${_roomCode ?? widget.roomId}-${bedNumber.toString().padLeft(3, '0')}';
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

  void _showEditBedDialog(BuildContext ctx, BedModel bed) {
    final bedCodeCtrl = TextEditingController(text: bed.bedCode);
    final nameCtrl = TextEditingController(text: bed.occupant?.name ?? '');
    final staffIdCtrl = TextEditingController(text: bed.occupant?.staffId ?? '');
    bool isSaving = false;

    showDialog(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setS) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Edit Bed Details', style: GoogleFonts.inter(color: AppTheme.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: bedCodeCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Bed ID (Code)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nameCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Occupant Name',
                  hintText: 'Enter name (creates new staff if vacant)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: staffIdCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Occupant ID (Staff ID)',
                  hintText: 'Enter ID',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dCtx),
              child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                final newBedCode = bedCodeCtrl.text.trim();
                final newName = nameCtrl.text.trim();
                final newStaffId = staffIdCtrl.text.trim();

                if (newBedCode.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Bed ID cannot be empty')));
                  return;
                }

                setS(() => isSaving = true);
                try {
                  // 1. Update Bed Code if changed
                  if (newBedCode != bed.bedCode) {
                    await _bedService.updateBedCode(bed.id, newBedCode);
                  }

                  // 2. Handle Staff Updates
                  if (bed.isOccupied && bed.occupant != null) {
                    // Update existing staff
                    Map<String, dynamic> updates = {};
                    if (newName.isNotEmpty && newName != bed.occupant!.name) {
                      updates['name'] = newName;
                    }
                    if (newStaffId.isNotEmpty && newStaffId != bed.occupant!.staffId) {
                      updates['staff_id'] = newStaffId;
                    }
                    
                    if (updates.isNotEmpty) {
                      await _staffService.update(bed.occupant!.id, updates);
                    }
                  } else {
                    // Bed is vacant or occupant is missing, but user provided a name -> Create and assign
                    if (newName.isNotEmpty) {
                      final generatedStaffId = newStaffId.isNotEmpty ? newStaffId : 'TEMP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                      
                      final newStaff = await _staffService.create(StaffModel(
                        id: '',
                        staffId: generatedStaffId,
                        name: newName,
                        status: 'Active',
                        createdAt: DateTime.now(),
                      ));
                      await _bedService.assignStaff(
                        bedId: bed.id,
                        staffId: newStaff.id,
                        bedStatus: 'FULL',
                      );
                      await ShiftService().logShift(
                        staffId: newStaff.id,
                        fromBedId: null,
                        toBedId: bed.id,
                        shiftDate: DateTime.now(),
                        reason: 'Initial assignment via edit',
                      );
                    } else if (newStaffId.isNotEmpty) {
                       if (ctx.mounted) {
                         ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please provide a name to create a new staff member')));
                       }
                       setS(() => isSaving = false);
                       return;
                    }
                  }

                  if (ctx.mounted) {
                    Navigator.pop(dCtx);
                  }
                  await _load();
                } catch (e) {
                  setS(() => isSaving = false);
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              style: ElevatedButton.styleFrom(minimumSize: Size.zero),
              child: isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bed_outlined, color: AppTheme.textMuted, size: 56),
            const SizedBox(height: 16),
            Text('No beds in this room',
                style: GoogleFonts.inter(
                    color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Tap the + button to add a bed',
                style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _StaffListTile extends StatelessWidget {
  final BedModel bed;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  const _StaffListTile({required this.bed, required this.isAdmin, required this.onTap, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
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
                  Text(bed.occupant?.name ?? 'Unknown',
                      style: GoogleFonts.inter(
                          color: Colors.black87,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  Text(bed.occupant?.staffId ?? '',
                      style: GoogleFonts.inter(
                          color: AppTheme.textMuted, fontSize: 13)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Bed ${bed.bedNumber}',
                    style: GoogleFonts.inter(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                Text(bed.position,
                    style: GoogleFonts.inter(
                        color: AppTheme.textMuted, fontSize: 12)),
              ],
            ),
            if (isAdmin)
              IconButton(
                icon: const Icon(Icons.edit, color: AppTheme.primary, size: 20),
                onPressed: onEdit,
              )
          ],
        ),
      ),
    );
  }
}

class _VacantBedTile extends StatelessWidget {
  final BedModel bed;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  const _VacantBedTile({required this.bed, required this.isAdmin, required this.onTap, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.success.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.single_bed, color: AppTheme.success),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bed ${bed.bedNumber}',
                      style: GoogleFonts.inter(
                          color: Colors.black87,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  Text(kBedPositionLabels[bed.position] ?? bed.position,
                      style: GoogleFonts.inter(
                          color: AppTheme.textMuted, fontSize: 13)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('VACANT',
                  style: GoogleFonts.inter(
                      color: AppTheme.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
            if (isAdmin)
              IconButton(
                icon: const Icon(Icons.edit, color: AppTheme.success, size: 20),
                onPressed: onEdit,
              )
          ],
        ),
      ),
    );
  }
}

class _HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(
        size.width / 4, size.height, size.width / 2, size.height - 20);
    path.quadraticBezierTo(
        size.width * 3 / 4, size.height - 40, size.width, size.height - 10);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _RoomStatChip extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _RoomStatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(height: 6),
          Text(
            value.toString(),
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
