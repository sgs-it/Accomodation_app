// lib/screens/rooms/rooms_list_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/room.dart';
import '../../providers/app_provider.dart';
import '../../services/room_service.dart';
import '../../widgets/loading_skeleton.dart';

class RoomsListScreen extends StatefulWidget {
  final String locationId;
  const RoomsListScreen({super.key, required this.locationId});

  @override
  State<RoomsListScreen> createState() => _RoomsListScreenState();
}

class _RoomsListScreenState extends State<RoomsListScreen> {
  bool _loading = true;
  List<RoomModel> _rooms = [];
  String? _locationName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final provider = context.read<AppProvider>();
    await provider.loadRoomsForLocation(widget.locationId);
    _rooms = provider.rooms;
    _locationName = provider.locations
        .firstWhere((l) => l.id == widget.locationId,
            orElse: () => provider.locations.first)
        .name;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.go('/dashboard'),
          color: AppTheme.textSecondary,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_locationName ?? widget.locationId,
                style: GoogleFonts.inter(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
            Text('Rooms', style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
        actions: [
          if (provider.isAdmin)
            IconButton(
              icon: const Icon(Icons.add, color: AppTheme.primary),
              tooltip: 'Add Room',
              onPressed: () => _showAddRoomDialog(context, provider),
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
              child: _rooms.isEmpty
                  ? _EmptyRooms(isAdmin: provider.isAdmin, onAdd: () => _showAddRoomDialog(context, provider))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _rooms.length,
                      itemBuilder: (ctx, i) => _RoomCard(
                        room: _rooms[i],
                        onTap: () => context.go('/rooms/${widget.locationId}/${_rooms[i].id}'),
                      ),
                    ),
            ),
    );
  }

  void _showAddRoomDialog(BuildContext ctx, AppProvider provider) {
    final roomNumCtrl = TextEditingController();
    final capacityCtrl = TextEditingController();
    DateTime? contractExpiry;

    showDialog(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setS) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Add Room',
              style: GoogleFonts.inter(color: AppTheme.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: roomNumCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Room Number'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: capacityCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Capacity (beds)'),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: dCtx,
                    initialDate: DateTime.now().add(const Duration(days: 365)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2040),
                  );
                  if (picked != null) setS(() => contractExpiry = picked);
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
                      Text(
                        contractExpiry != null
                            ? DateFormat('dd MMM yyyy').format(contractExpiry!)
                            : 'Contract Expiry (optional)',
                        style: GoogleFonts.inter(
                            color: contractExpiry != null
                                ? AppTheme.textPrimary
                                : AppTheme.textMuted,
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
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
                final rn = roomNumCtrl.text.trim();
                final cap = int.tryParse(capacityCtrl.text.trim()) ?? 0;
                if (rn.isEmpty || cap <= 0) return;
                Navigator.pop(dCtx);
                final roomCode = '${widget.locationId}-$rn';
                try {
                  await RoomService().create(RoomModel(
                    id: '',
                    roomCode: roomCode,
                    locationId: widget.locationId,
                    roomNumber: rn,
                    capacity: cap,
                    contractExpiry: contractExpiry,
                  ));
                  await _load();
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
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

class _RoomCard extends StatelessWidget {
  final RoomModel room;
  final VoidCallback onTap;
  const _RoomCard({required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pct = room.capacity > 0 ? room.occupiedCount / room.capacity : 0.0;
    final expiring = room.contractExpiry != null &&
        room.contractExpiry!.difference(DateTime.now()).inDays < 90;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: expiring ? AppTheme.warning.withOpacity(0.5) : AppTheme.divider,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(room.roomCode,
                    style: GoogleFonts.inter(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                Text('${room.occupiedCount}/${room.capacity} beds',
                    style: GoogleFonts.inter(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 5,
                backgroundColor: AppTheme.divider,
                valueColor: AlwaysStoppedAnimation<Color>(
                    pct < 0.7 ? AppTheme.success : AppTheme.danger),
              ),
            ),
            if (room.contractExpiry != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: 12,
                    color: expiring ? AppTheme.warning : AppTheme.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Contract: ${DateFormat('dd MMM yyyy').format(room.contractExpiry!)}',
                    style: GoogleFonts.inter(
                      color: expiring ? AppTheme.warning : AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  if (expiring) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('Expiring soon',
                          style: GoogleFonts.inter(
                              color: AppTheme.warning,
                              fontSize: 9,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyRooms extends StatelessWidget {
  final bool isAdmin;
  final VoidCallback onAdd;
  const _EmptyRooms({required this.isAdmin, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.meeting_room_outlined, color: AppTheme.textMuted, size: 56),
          const SizedBox(height: 16),
          Text('No rooms yet',
              style: GoogleFonts.inter(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 8),
          Text(isAdmin ? 'Tap the + button to add a room' : 'No rooms in this location yet',
              style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}
