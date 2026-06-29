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
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.go('/dashboard'),
          color: AppTheme.textSecondary,
        ),
        title: Text(
          _title,
          style: GoogleFonts.inter(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by bed, room, staff name or ID...',
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMuted),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppTheme.textMuted),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                filled: true,
                fillColor: AppTheme.bgCard,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primary),
                ),
              ),
            ),
          ),
          
          Expanded(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(16),
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
                    backgroundColor: AppTheme.bgCard,
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
                                    color: AppTheme.textMuted.withOpacity(0.3),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No beds found',
                                    style: GoogleFonts.inter(
                                      color: AppTheme.textSecondary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Try adjusting your search query.',
                                    style: GoogleFonts.inter(
                                      color: AppTheme.textMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
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
    return Card(
      color: AppTheme.bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.divider),
      ),
      margin: const EdgeInsets.only(bottom: 12),
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
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${bed.locationName ?? "Unknown Location"} • Room ${bed.roomCode ?? "Unknown"}',
                            style: GoogleFonts.inter(
                              color: AppTheme.textSecondary,
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
                            color: AppTheme.textPrimary,
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
