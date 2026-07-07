// lib/screens/beds/beds_filter_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../models/bed.dart';
import '../../services/bed_service.dart';
import '../../widgets/loading_skeleton.dart';

class BedsFilterScreen extends StatefulWidget {
  final String filter; // 'all', 'occupied', 'vacant', 'leave'
  const BedsFilterScreen({super.key, required this.filter});

  @override
  State<BedsFilterScreen> createState() => _BedsFilterScreenState();
}

class _BedsFilterScreenState extends State<BedsFilterScreen> {
  final _bedService = BedService();
  bool _loading = true;
  List<BedModel> _beds = [];
  List<BedModel> _filteredBeds = [];
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      String? queryStatus;
      if (widget.filter == 'occupied') {
        queryStatus = 'FULL';
      } else if (widget.filter == 'vacant') {
        queryStatus = 'VACANT';
      } else if (widget.filter == 'leave') {
        queryStatus = 'VACATION';
      }
      
      final result = await _bedService.getAllFiltered(status: queryStatus);
      setState(() {
        _beds = result;
        _filteredBeds = result;
      });
    } catch (_) {
      // Handle error if needed
    } finally {
      setState(() => _loading = false);
    }
  }

  void _onSearch() {
    final query = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredBeds = _beds;
      } else {
        _filteredBeds = _beds.where((b) {
          final codeMatch = b.bedCode.toLowerCase().contains(query);
          final roomMatch = (b.roomCode ?? '').toLowerCase().contains(query);
          final occupantMatch = b.occupant != null &&
              (b.occupant!.name.toLowerCase().contains(query) ||
                  b.occupant!.staffId.toLowerCase().contains(query));
          return codeMatch || roomMatch || occupantMatch;
        }).toList();
      }
    });
  }

  String get _title {
    switch (widget.filter) {
      case 'occupied':
        return 'Occupied Beds';
      case 'vacant':
        return 'Vacant Beds';
      case 'leave':
        return 'Beds on Leave';
      default:
        return 'Total Beds';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
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
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => context.go('/dashboard'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _title,
                          style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          Transform.translate(
            offset: const Offset(0, -30),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Color(0xFF1E293B), fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search by bed, room, staff name or ID...',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Color(0xFF94A3B8)),
                            onPressed: () => _searchCtrl.clear(),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
              ),
            ),
          ),
          
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -20),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        children: [
                          SkeletonCard(),
                          SkeletonCard(),
                          SkeletonCard(),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: AppTheme.primary,
                      backgroundColor: Colors.white,
                      onRefresh: _load,
                      child: _filteredBeds.isEmpty
                          ? Center(
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.bed_outlined,
                                      size: 64,
                                      color: Colors.grey.withValues(alpha: 0.3),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No beds found',
                                      style: GoogleFonts.inter(
                                        color: Colors.black54,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Try adjusting your search query.',
                                      style: GoogleFonts.inter(
                                        color: Colors.black45,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              itemCount: _filteredBeds.length,
                              itemBuilder: (context, index) {
                                final bed = _filteredBeds[index];
                                return _BedListTile(
                                  bed: bed,
                                  onTap: () {
                                    if (bed.locationId != null && bed.roomId.isNotEmpty) {
                                      context.go('/rooms/${bed.locationId}/${bed.roomId}');
                                    }
                                  },
                                );
                              },
                            ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BedListTile extends StatelessWidget {
  final BedModel bed;
  final VoidCallback onTap;

  const _BedListTile({required this.bed, required this.onTap});

  Color get _statusColor {
    switch (bed.status) {
      case 'FULL':
        return AppTheme.danger;
      case 'VACATION':
        return AppTheme.vacation;
      case 'MAINTENANCE':
        return AppTheme.warning;
      default:
        return AppTheme.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.bed_rounded,
                          color: _statusColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bed.bedCode,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF1E293B),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${bed.locationName ?? "Unknown Location"} • Room ${bed.roomCode ?? "Unknown"}',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      bed.status,
                      style: GoogleFonts.inter(
                        color: _statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (bed.occupant != null) ...[
                const SizedBox(height: 12),
                const Divider(color: AppTheme.divider, height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppTheme.primary,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.inter(
                            color: const Color(0xFF1E293B),
                            fontSize: 13,
                          ),
                          children: [
                            TextSpan(
                              text: bed.occupant!.name,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            TextSpan(
                              text: ' (ID: ${bed.occupant!.staffId})',
                              style: const TextStyle(color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
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
