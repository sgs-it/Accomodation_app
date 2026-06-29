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
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dashboard',
                style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            Text('Staff Accommodation Overview',
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
        actions: [
          Consumer<AppProvider>(
            builder: (_, p, __) => p.isAdmin
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.download_rounded, color: AppTheme.textSecondary),
                        tooltip: 'Export Excel',
                        onPressed: () async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Generating Excel export...')),
                          );
                          try {
                            await ExportService().exportData();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Export failed: $e')),
                              );
                            }
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.person_add_outlined,
                            color: AppTheme.textSecondary),
                        tooltip: 'Manage Users',
                        onPressed: () => context.go('/users'),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.textSecondary),
            tooltip: 'Sign Out',
            onPressed: () async {
              await context.read<AppProvider>().authService.signOut();
              if (mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (ctx, provider, _) {
          if (provider.loading) {
            return const _DashboardSkeleton();
          }
          return RefreshIndicator(
            color: AppTheme.primary,
            backgroundColor: AppTheme.bgCard,
            onRefresh: provider.loadLocations,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Role badge
                _RoleBadge(isAdmin: provider.isAdmin),
                const SizedBox(height: 20),

                // Summary stats grid
                Text('Overview',
                    style: GoogleFonts.inter(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    StatCard(
                      label: 'Total Beds',
                      value: provider.totalBeds,
                      color: AppTheme.primary,
                      icon: Icons.bed_rounded,
                    ),
                    StatCard(
                      label: 'Occupied',
                      value: provider.totalOccupied,
                      color: AppTheme.danger,
                      icon: Icons.person_rounded,
                    ),
                    StatCard(
                      label: 'Vacant',
                      value: provider.totalVacant,
                      color: AppTheme.success,
                      icon: Icons.check_circle_outline,
                    ),
                    StatCard(
                      label: 'On Leave',
                      value: provider.totalOnLeave,
                      color: AppTheme.vacation,
                      icon: Icons.flight_takeoff_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Locations list
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Locations',
                        style: GoogleFonts.inter(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    if (provider.isAdmin)
                      TextButton.icon(
                        onPressed: () => _showAddLocationDialog(context, provider),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add'),
                        style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primary),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (provider.locations.isEmpty)
                  _EmptyLocations(isAdmin: provider.isAdmin)
                else
                  ...provider.locations
                      .map((loc) => _LocationCard(location: loc)),
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
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Location',
            style: GoogleFonts.inter(color: AppTheme.textPrimary)),
        content: Column(
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
              if (idCtrl.text.isEmpty || nameCtrl.text.isEmpty) return;
              Navigator.pop(dialogCtx);
              try {
                await LocationService().create(LocationModel(
                  id: idCtrl.text.trim().toUpperCase(),
                  name: nameCtrl.text.trim(),
                  managerName: managerCtrl.text.trim().isEmpty
                      ? null
                      : managerCtrl.text.trim(),
                ));
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

  @override
  Widget build(BuildContext context) {
    final occupancyPct = location.totalBeds > 0
        ? location.occupiedBeds / location.totalBeds
        : 0.0;

    return GestureDetector(
      onTap: () => context.go('/rooms/${location.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.location_city_rounded,
                      color: AppTheme.primary, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(location.name,
                          style: GoogleFonts.inter(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      if (location.managerName != null)
                        Text(location.managerName!,
                            style: GoogleFonts.inter(
                                color: AppTheme.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCardLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(location.id,
                      style: GoogleFonts.inter(
                          color: AppTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Occupancy bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: occupancyPct,
                minHeight: 6,
                backgroundColor: AppTheme.divider,
                valueColor:
                    AlwaysStoppedAnimation<Color>(_progressColor(occupancyPct)),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _MiniStat(
                    label: 'Total', value: location.totalBeds, color: AppTheme.textSecondary),
                _MiniStat(
                    label: 'Occupied', value: location.occupiedBeds, color: AppTheme.danger),
                _MiniStat(
                    label: 'Vacant', value: location.vacantBeds, color: AppTheme.success),
                _MiniStat(
                    label: 'On Leave', value: location.onLeaveBeds, color: AppTheme.vacation),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _progressColor(double pct) {
    if (pct < 0.6) return AppTheme.success;
    if (pct < 0.85) return AppTheme.warning;
    return AppTheme.danger;
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _MiniStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value.toString(),
            style: GoogleFonts.inter(
                color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label,
            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10)),
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
        color: isAdmin
            ? AppTheme.primary.withOpacity(0.1)
            : AppTheme.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isAdmin
                ? AppTheme.primary.withOpacity(0.3)
                : AppTheme.accent.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isAdmin ? Icons.admin_panel_settings : Icons.visibility,
              color: isAdmin ? AppTheme.primary : AppTheme.accent, size: 16),
          const SizedBox(width: 8),
          Text(
            isAdmin ? 'Admin — Full Access' : 'Viewer — Can Add Data',
            style: GoogleFonts.inter(
              color: isAdmin ? AppTheme.primary : AppTheme.accent,
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

