// lib/screens/dashboard/dashboard_screen.dart

import 'package:flutter/material.dart';
import '../../services/location_service.dart';
import '../../services/export_service.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/location.dart';
import '../../providers/app_provider.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/loading_skeleton.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadLocations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Light grey/white background
      body: Consumer<AppProvider>(
        builder: (ctx, provider, _) {
          if (provider.loading) {
            return const _DashboardSkeleton();
          }
          return RefreshIndicator(
            color: AppTheme.primary,
            backgroundColor: Colors.white,
            onRefresh: provider.loadLocations,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Stack(
                    children: [
                      // Wavy Purple Background Header
                      ClipPath(
                        clipper: _HeaderClipper(),
                        child: Container(
                          height: 280,
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            gradient: AppTheme.dashboardHeaderGradient,
                            image: DecorationImage(
                              image: AssetImage('assets/images/city_bg.png'), // fallback to empty if missing
                              fit: BoxFit.cover,
                              opacity: 0.1,
                            ),
                          ),
                        ),
                      ),
                      // Header Content
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
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Welcome, ${provider.isAdmin ? 'Admin' : (provider.myStaffRecord?['name']?.toString().split(' ').first ?? 'Staff')} 👋',
                                            style: GoogleFonts.inter(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold)),
                                        Text('Staff Accommodation Overview',
                                            style: GoogleFonts.inter(
                                                color: Colors.white70, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  // Action Buttons
                                  if (provider.isAdmin) ...[
                                    _ActionBtn(
                                      icon: Icons.download_rounded,
                                      onTap: () async {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating Excel...')));
                                        try { await ExportService().exportData(); } catch (_) {}
                                      }
                                    ),
                                    const SizedBox(width: 10),
                                    _ActionBtn(icon: Icons.person_add_outlined, onTap: () => context.go('/users'), color: AppTheme.accent),
                                    const SizedBox(width: 10),
                                  ],
                                  _ActionBtn(
                                    icon: Icons.logout,
                                    onTap: () async {
                                      await context.read<AppProvider>().authService.signOut();
                                      if (context.mounted) context.go('/login');
                                    },
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              // Role badge
                              _RoleBadge(isAdmin: provider.isAdmin),
                            ],
                          ),
                        ),
                      ),
                      // Main Content Area overlapping header
                      Container(
                        margin: const EdgeInsets.only(top: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Summary stats grid
                            Text('Overview',
                                style: GoogleFonts.inter(
                                    color: const Color(0xFF1E293B),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                int columns = constraints.maxWidth > 800 ? 4 : (constraints.maxWidth > 500 ? 3 : 2);
                                double aspectRatio = constraints.maxWidth > 800 ? 2.2 : (constraints.maxWidth > 500 ? 1.4 : 0.95);
                                return GridView.count(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: aspectRatio,
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  children: [
                                    StatCard(
                                      label: 'Total Beds',
                                      value: provider.totalBeds,
                                      color: AppTheme.primary,
                                      icon: Icons.bed_rounded,
                                      sparklineData: const [10, 20, 15, 30, 25, 40, 50, 45, 60],
                                      onTap: () => context.go('/beds-overview/all'),
                                    ),
                                    StatCard(
                                      label: 'Occupied',
                                      value: provider.totalOccupied,
                                      color: AppTheme.danger,
                                      icon: Icons.person_rounded,
                                      sparklineData: const [30, 25, 40, 35, 50, 45, 60, 55, 70],
                                      onTap: () => context.go('/beds-overview/occupied'),
                                    ),
                                    StatCard(
                                      label: 'Vacant',
                                      value: provider.totalVacant,
                                      color: AppTheme.success,
                                      icon: Icons.check_circle_outline,
                                      sparklineData: const [50, 45, 60, 55, 70, 65, 80, 75, 90],
                                      onTap: () => context.go('/beds-overview/vacant'),
                                    ),
                                    StatCard(
                                      label: 'On Leave',
                                      value: provider.totalOnLeave,
                                      color: AppTheme.vacation,
                                      icon: Icons.flight_takeoff_rounded,
                                      sparklineData: const [20, 25, 15, 30, 20, 35, 25, 40, 30],
                                      onTap: () => context.push('/on-leave'),
                                    ),
                                  ],
                                );
                              },
                            ),
                            // Locations list
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Locations',
                                    style: GoogleFonts.inter(
                                        color: const Color(0xFF1E293B),
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                if (provider.isAdmin)
                                  TextButton.icon(
                                    onPressed: () => _showAddLocationDialog(context, provider),
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Add Location'),
                                    style: TextButton.styleFrom(
                                        foregroundColor: AppTheme.vacation),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (provider.locations.isEmpty)
                              _EmptyLocations(isAdmin: provider.isAdmin)
                            else
                              ...provider.locations
                                  .map((loc) => _LocationCard(location: loc)),
                            const SizedBox(height: 100), // padding for bottom nav
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddLocationDialog(BuildContext ctx, AppProvider provider) {
    final idCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final managerCtrl = TextEditingController();
    final roomsCtrl = TextEditingController(text: '0');
    final bedsCtrl = TextEditingController(text: '4');

    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Location',
            style: GoogleFonts.inter(color: AppTheme.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: idCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Location Code (e.g. AQZ)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Location Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: managerCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Manager Name (optional)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: roomsCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Number of Rooms to Create'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bedsCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Beds per Room'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (idCtrl.text.isEmpty || nameCtrl.text.isEmpty) return;
              final numRooms = int.tryParse(roomsCtrl.text) ?? 0;
              final numBeds = int.tryParse(bedsCtrl.text) ?? 0;
              Navigator.pop(dialogCtx);
              try {
                await LocationService().createWithRoomsAndBeds(
                  location: LocationModel(
                    id: idCtrl.text.trim().toUpperCase(),
                    name: nameCtrl.text.trim(),
                    managerName: managerCtrl.text.trim().isEmpty
                        ? null
                        : managerCtrl.text.trim(),
                  ),
                  numRooms: numRooms,
                  numBeds: numBeds,
                );
                await provider.loadLocations();
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
    );
  }
}

class _LocationCard extends StatelessWidget {
  final LocationModel location;
  const _LocationCard({required this.location});

  void _showEditLocationDialog(BuildContext ctx, AppProvider provider) {
    final nameCtrl = TextEditingController(text: location.name);
    final managerCtrl = TextEditingController(text: location.managerName ?? '');

    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Location',
            style: GoogleFonts.inter(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Location Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: managerCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Manager Name (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              Navigator.pop(dialogCtx);
              try {
                await LocationService().update(location.id, {
                  'name': nameCtrl.text.trim(),
                  'manager_name': managerCtrl.text.trim().isEmpty
                      ? null
                      : managerCtrl.text.trim(),
                });
                await provider.loadLocations();
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(minimumSize: Size.zero),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteLocationDialog(BuildContext ctx, AppProvider provider) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Location?',
            style: GoogleFonts.inter(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete "${location.name}"? This will permanently delete all rooms, beds, and occupant assignments in this location. This action cannot be undone.',
          style: GoogleFonts.inter(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await LocationService().delete(location.id);
                await provider.loadLocations();
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              minimumSize: Size.zero,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isAdmin = provider.isAdmin;
    
    // Calculate percentages for progress bar
    final total = location.totalBeds > 0 ? location.totalBeds : 1; // avoid div by 0
    final occPct = location.occupiedBeds / total;
    final vacPct = location.vacantBeds / total;
    final leavePct = location.onLeaveBeds / total;

    return GestureDetector(
      onTap: () => context.go('/rooms/${location.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E243A), // Dark purple-ish background for cards
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Avatar (Building)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C3552),
                    shape: BoxShape.circle,
                    image: const DecorationImage(
                      image: AssetImage('assets/images/building.png'), // Will fallback if not present
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(Colors.black38, BlendMode.darken),
                    ),
                  ),
                  child: const Icon(Icons.business, color: Colors.white54),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(location.name,
                          style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      Text(location.managerName ?? 'Manager',
                          style: GoogleFonts.inter(
                              color: const Color(0xFF94A3B8), fontSize: 12)),
                    ],
                  ),
                ),
                // Location ID Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(location.id,
                      style: GoogleFonts.inter(
                          color: AppTheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
                if (isAdmin)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white54, size: 18),
                    color: AppTheme.bgCard,
                    onSelected: (val) {
                      if (val == 'edit') {
                        _showEditLocationDialog(context, provider);
                      } else if (val == 'delete') {
                        _showDeleteLocationDialog(context, provider);
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit', style: GoogleFonts.inter(color: AppTheme.textPrimary)),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete', style: GoogleFonts.inter(color: AppTheme.danger)),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Multi-colored segmented progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  Expanded(
                    flex: (occPct * 100).toInt(),
                    child: Container(height: 6, color: AppTheme.danger),
                  ),
                  Expanded(
                    flex: (vacPct * 100).toInt(),
                    child: Container(height: 6, color: AppTheme.success),
                  ),
                  Expanded(
                    flex: (leavePct * 100).toInt(),
                    child: Container(height: 6, color: AppTheme.vacation),
                  ),
                  if (total == 1 && location.totalBeds == 0)
                    Expanded(
                      flex: 1,
                      child: Container(height: 6, color: AppTheme.divider),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Bottom stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _MiniStat(label: 'Total', value: location.totalBeds, color: const Color(0xFF8B5CF6)),
                _MiniStat(label: 'Occupied', value: location.occupiedBeds, color: AppTheme.danger),
                _MiniStat(label: 'Vacant', value: location.vacantBeds, color: AppTheme.success),
                _MiniStat(label: 'On Leave', value: location.onLeaveBeds, color: AppTheme.vacation),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value.toString(),
            style: GoogleFonts.inter(
                color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        Text(label,
            style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 10)),
      ],
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final bool isAdmin;
  const _RoleBadge({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isAdmin ? Icons.admin_panel_settings : Icons.visibility,
              color: Colors.lightBlueAccent, size: 16),
          const SizedBox(width: 8),
          Text(
            isAdmin ? 'Admin — Full Access' : 'Viewer — Can Add Data',
            style: GoogleFonts.inter(
              color: Colors.lightBlueAccent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLocations extends StatelessWidget {
  final bool isAdmin;
  const _EmptyLocations({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          const Icon(Icons.location_off, color: AppTheme.textMuted, size: 48),
          const SizedBox(height: 16),
          Text('No locations yet',
              style: GoogleFonts.inter(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            isAdmin
                ? 'Tap "Add" to create your first location'
                : 'Contact your admin to add locations',
            style: GoogleFonts.inter(
                color: AppTheme.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(
                4,
                (_) => const LoadingSkeleton(height: double.infinity,
                    radius: 16)),
          ),
          const SizedBox(height: 24),
          const SkeletonCard(),
          const SkeletonCard(),
          const SkeletonCard(),
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

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final bool hasBadge;

  const _ActionBtn({
    required this.icon,
    required this.onTap,
    this.color = AppTheme.vacation,
    this.hasBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          if (hasBadge)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppTheme.danger,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '3',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


