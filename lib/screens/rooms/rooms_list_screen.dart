// lib/screens/rooms/rooms_list_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/room.dart';
import '../../models/location.dart';
import '../../providers/app_provider.dart';
import '../../services/room_service.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/stat_card.dart';

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
    final isAdmin = provider.isAdmin;
    
    int totalCapacity = 0;
    int occupied = 0;
    for (var r in _rooms) {
      totalCapacity += r.effectiveCapacity;
      occupied += r.occupiedCount;
    }
    int availableBeds = totalCapacity - occupied;

    final loc = provider.locations.firstWhere(
        (l) => l.id == widget.locationId,
        orElse: () => LocationModel(id: '', name: ''));
    final manager = loc.managerName;

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
                                onPressed: () => context.go('/dashboard'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_locationName ?? widget.locationId,
                                        style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(manager != null && manager.isNotEmpty
                                        ? 'Managed by: $manager'
                                        : 'Rooms list',
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
                                    icon: const Icon(Icons.add, color: Color(0xFF4C1D95)),
                                    onPressed: () => _showAddRoomDialog(context, provider),
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
                    margin: const EdgeInsets.only(top: 125), // Push content down to clear title and add button
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            double aspectRatio = constraints.maxWidth > 800 ? 3.0 : (constraints.maxWidth > 500 ? 2.0 : 1.25);
                            return GridView.count(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: aspectRatio,
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                StatCard(
                                  label: 'Total Rooms',
                                  value: _rooms.length,
                                  icon: Icons.meeting_room,
                                  color: AppTheme.primary,
                                  trendText: '',
                                  trendUp: true,
                                ),
                                StatCard(
                                  label: 'Available Beds',
                                  value: availableBeds,
                                  icon: Icons.single_bed,
                                  color: AppTheme.success,
                                  trendText: '',
                                  trendUp: true,
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        // Rooms List
                        _loading
                            ? const Column(children: [
                                SkeletonCard(),
                                SkeletonCard(),
                                SkeletonCard()
                              ])
                            : _rooms.isEmpty
                                ? _EmptyRooms(isAdmin: provider.isAdmin, onAdd: () => _showAddRoomDialog(context, provider))
                                : ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _rooms.length,
                                    itemBuilder: (ctx, i) => _RoomCard(
                                      room: _rooms[i],
                                      onTap: () => context.go('/rooms/${widget.locationId}/${_rooms[i].id}'),
                                    ),
                                  ),
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
    final pct = room.occupancyRate;
    final expiring = room.contractExpiry != null &&
        room.contractExpiry!.difference(DateTime.now()).inDays < 90;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: expiring ? AppTheme.warning.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.meeting_room, color: AppTheme.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(room.roomCode,
                            style: GoogleFonts.inter(
                                color: Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('Capacity: ${room.effectiveCapacity}',
                            style: GoogleFonts.inter(
                                color: AppTheme.textMuted, fontSize: 12)),
                        if (room.contractNumber != null && room.contractNumber!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text('Contract No: ${room.contractNumber}',
                              style: GoogleFonts.inter(
                                  color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: pct < 1.0 ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${room.vacantCount} empty',
                    style: GoogleFonts.inter(
                      color: pct < 1.0 ? AppTheme.success : AppTheme.danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                    pct < 0.7 ? AppTheme.success : (pct < 1.0 ? AppTheme.warning : AppTheme.danger)),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(pct * 100).toInt()}% Occupied',
                    style: GoogleFonts.inter(
                        color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
                Text('${room.occupiedCount}/${room.effectiveCapacity} beds',
                    style: GoogleFonts.inter(
                        color: Colors.black87, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
            if (room.contractExpiry != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: expiring ? AppTheme.warning.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_outlined,
                      size: 14,
                      color: expiring ? AppTheme.warning : AppTheme.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Contract: ${DateFormat('dd MMM yyyy').format(room.contractExpiry!)}',
                      style: GoogleFonts.inter(
                        color: expiring ? AppTheme.warning : AppTheme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (expiring) ...[
                      const Spacer(),
                      Text('Expiring soon',
                          style: GoogleFonts.inter(
                              color: AppTheme.warning,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
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
                  color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 8),
          Text(isAdmin ? 'Tap the + button to add a room' : 'No rooms in this location yet',
              style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13)),
        ],
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
