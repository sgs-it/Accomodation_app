// lib/screens/staff/staff_list_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../models/staff.dart';
import '../../providers/app_provider.dart';
import '../../services/staff_service.dart';
import '../../services/pending_service.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/stat_card.dart';

class StaffListScreen extends StatefulWidget {
  const StaffListScreen({super.key});

  @override
  State<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends State<StaffListScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  bool _loading = false;
  List<StaffModel> _staff = [];
  List<PendingChange> _myPending = [];
  // staffId -> list of pending changes
  Map<String, List<PendingChange>> _pendingByStaff = {};
  String _statusFilter = '';
  late TabController _tabController;
  List<Map<String, dynamic>> _admins = [];
  List<Map<String, dynamic>> _supervisors = [];
  int _unassignedCount = 0;

  @override
  void initState() {
    super.initState();
    final provider = context.read<AppProvider>();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final provider = context.read<AppProvider>();
    _staff = await StaffService().getAll(
      search: _searchCtrl.text.trim(),
      status: _statusFilter.isEmpty ? null : _statusFilter,
    );

    if (provider.isAdmin || provider.isSupervisor) {
      try {
        final rolesResp = await Supabase.instance.client
            .from('user_roles')
            .select('user_id, role, location:locations(name)')
            .eq('role', 'supervisor');
            
        final supervisorRoles = <String, String>{};
        for (final r in rolesResp) {
          final uid = r['user_id'] as String;
          final locName = (r['location'] as Map?)?['name'] as String? ?? 'No Location';
          supervisorRoles[uid] = locName;
        }

        _supervisors = _staff.where((s) => s.authUserId != null && supervisorRoles.containsKey(s.authUserId)).map((s) {
          return {
            'id': s.authUserId,
            'name': s.name,
            'email': s.staffId,
            'location': supervisorRoles[s.authUserId],
          };
        }).toList();
      } catch (e) {
        debugPrint('Error fetching supervisors: $e');
      }
    }

    if (provider.isAdmin) {
      // Load ALL pending changes and group by staff
      final all = await provider.pendingService.getAll(status: 'pending');
      _pendingByStaff = {};
      for (final c in all) {
        final sid = c.payload['staff_id']?.toString() ?? '';
        _pendingByStaff.putIfAbsent(sid, () => []).add(c);
      }
      try {
        final res = await Supabase.instance.client.rpc('get_admin_users');
        if (res != null) {
          _admins = List<Map<String, dynamic>>.from(
              (res as List).map((x) => Map<String, dynamic>.from(x)));
        }
      } catch (e) {
        debugPrint('Error fetching admins: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load admins: $e'),
              backgroundColor: AppTheme.danger,
              duration: const Duration(seconds: 10),
            ),
          );
        }
      }
      try {
        // Unassigned = On Leave staff with no bed assignment
        final uData = await Supabase.instance.client
            .from('staff')
            .select('id')
            .eq('status', 'On Leave');
        
        if (uData.isEmpty) {
          _unassignedCount = 0;
        } else {
          final staffIds = uData.map((s) => s['id']).toList();
          final activeAssignments = await Supabase.instance.client
              .from('bed_assignments')
              .select('staff_id')
              .inFilter('staff_id', staffIds);
              
          final assignedStaffIds = activeAssignments.map((a) => a['staff_id']).toSet();
          int count = 0;
          for (final row in uData) {
            if (!assignedStaffIds.contains(row['id'])) count++;
          }
          _unassignedCount = count;
        }
      } catch (e) {
        debugPrint('Error fetching unassigned: $e');
      }
      // Also refresh provider so dashboard/other screens stay in sync
      await provider.loadStaff();
      await provider.loadLocations();
    } else if (provider.isStaff) {
      _myPending = await provider.pendingService.getMyChanges();
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isAdmin = provider.isAdmin;
    final isStaff = provider.isStaff;

    if (isStaff) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Stack(
          children: [
            Column(
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
                            Expanded(
                              child: Text(
                                'My Profile',
                                style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.logout, color: Colors.white),
                              tooltip: 'Logout',
                              onPressed: () async {
                                await Supabase.instance.client.auth.signOut();
                                if (context.mounted) context.go('/login');
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                Transform.translate(
                  offset: const Offset(0, -20),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: const Color(0xFF8B5CF6),
                      labelColor: const Color(0xFF8B5CF6),
                      unselectedLabelColor: Colors.black54,
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      tabs: const [
                        Tab(text: 'My Info'),
                        Tab(text: 'My Requests'),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: Transform.translate(
                    offset: const Offset(0, -10),
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildStaffMyInfo(provider),
                        _buildMyRequestsTab(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final totalStaff = _staff.length;
    final onLeaveStaff = _staff.where((s) => s.status == 'On Leave').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B5CF6),
        title: Text(provider.isAdmin ? 'Staff & Management' : 'Staff & Supervisors',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: [
            const Tab(text: 'Staff Members'),
            Tab(text: provider.isAdmin ? 'Admins & Supervisors' : 'Supervisors'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Staff Tab
          RefreshIndicator(
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
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Staff Management',
                                        style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text('Manage and view staff details',
                                        style: GoogleFonts.inter(
                                            color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                                  ],
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
                    margin: const EdgeInsets.only(top: 100),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Summary stats grid
                        LayoutBuilder(
                          builder: (context, constraints) {
                            double aspectRatio = constraints.maxWidth > 800 ? 2.6 : (constraints.maxWidth > 500 ? 1.6 : 0.72);
                            return GridView.count(
                              crossAxisCount: 3,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: aspectRatio,
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                          children: [
                            StatCard(
                              label: 'Total\nStaff',
                              value: totalStaff,
                              icon: Icons.people,
                              color: AppTheme.primary,
                              trendText: '',
                              trendUp: true,
                              sparklineData: const [3.0, 4.0, 3.0, 5.0, 4.0, 6.0, 5.0],
                            ),
                            StatCard(
                              label: 'On\nLeave',
                              value: onLeaveStaff,
                              icon: Icons.event_busy,
                              color: AppTheme.warning,
                              trendText: '',
                              trendUp: false,
                              onTap: () => context.push('/on-leave'),
                              sparklineData: const [2.0, 1.0, 2.0, 3.0, 2.0, 1.0, 2.0],
                            ),
                            StatCard(
                              label: 'Unassigned\nStaff',
                              value: _unassignedCount,
                              icon: Icons.beach_access,
                              color: AppTheme.accent,
                              trendText: '',
                              trendUp: false,
                              onTap: () => context.push('/unassigned'),
                            ),
                          ],
                            );
                          }
                        ),
                        const SizedBox(height: 24),
                        // Search Bar
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4C1D95).withValues(alpha: 0.08),
                                blurRadius: 15,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            style: GoogleFonts.inter(color: Colors.black87),
                            decoration: InputDecoration(
                              hintText: 'Search by name, ID or location...',
                              hintStyle: GoogleFonts.inter(
                                color: Colors.black54, 
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                              prefixIcon: const Icon(Icons.search, color: Color(0xFF4C1D95)),
                              suffixIcon: _searchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, color: Colors.black38),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        _load();
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              filled: true,
                              fillColor: Colors.transparent,
                              contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onChanged: (_) => _load(),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Staff List
                        _loading
                            ? const Column(children: [
                                SkeletonCard(),
                                SkeletonCard(),
                                SkeletonCard()
                              ])
                            : _staff.isEmpty
                                ? _EmptyStaff(onAdd: () => _showAddStaffDialog(context, provider))
                                : ListView.builder(
                                    padding: const EdgeInsets.only(bottom: 120),
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _staff.length,
                                    itemBuilder: (ctx, i) {
                                      final sid = _staff[i].staffId;
                                      final pending = _pendingByStaff[sid] ?? [];
                                      return _StaffCard(
                                        staff: _staff[i],
                                        isAdmin: isAdmin,
                                        pendingCount: pending.length,
                                        onTap: () => context.go('/staff/${_staff[i].id}'),
                                        onDelete: isAdmin
                                            ? () async {
                                                setState(() => _loading = true);
                                                try {
                                                  await StaffService().delete(_staff[i].id);
                                                  
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Staff deleted successfully')),
                                                    );
                                                  }
                                                } catch (e) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('Failed to delete staff: $e'),
                                                        backgroundColor: AppTheme.danger,
                                                      ),
                                                    );
                                                  }
                                                } finally {
                                                  _load();
                                                  provider.loadLocations();
                                                }
                                              }
                                            : null,
                                      );
                                    },
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
      // Management Tab
      _buildManagementTab(),
        ],
      ),
    );
  }

  Widget _buildManagementTab() {
    final provider = context.watch<AppProvider>();
    final isAdmin = provider.isAdmin;
    
    if (_loading) return const Center(child: CircularProgressIndicator());
    
    if (isAdmin && _admins.isEmpty && _supervisors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.admin_panel_settings_outlined, color: AppTheme.textMuted, size: 56),
            const SizedBox(height: 16),
            Text('No Management Accounts',
                style: GoogleFonts.inter(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    } else if (!isAdmin && _supervisors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.supervisor_account_outlined, color: AppTheme.textMuted, size: 56),
            const SizedBox(height: 16),
            Text('No Supervisors',
                style: GoogleFonts.inter(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      children: [
        if (isAdmin && _admins.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Admins', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
          ),
          ..._admins.map((admin) => _buildAdminCard(admin)),
          const SizedBox(height: 24),
        ],
        if (_supervisors.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Supervisors', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
          ),
          ..._supervisors.map((supervisor) => _buildSupervisorCard(supervisor)),
        ]
      ],
    );
  }

  Widget _buildSupervisorCard(Map<String, dynamic> supervisor) {
    final name = supervisor['name'] as String? ?? 'Unknown';
    final email = supervisor['email'] as String? ?? 'Unknown';
    final location = supervisor['location'] as String? ?? 'No Location';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.supervisor_account, color: AppTheme.accent),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: GoogleFonts.inter(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(email,
                    style: GoogleFonts.inter(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'SUPERVISOR • $location',
                    style: GoogleFonts.inter(
                      color: AppTheme.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCard(Map<String, dynamic> admin) {
    final email = admin['email'] as String? ?? 'Unknown';
        final date = admin['created_at'] != null 
          ? DateTime.tryParse(admin['created_at'].toString()) 
          : null;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.admin_panel_settings, color: AppTheme.accent),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Admin User',
                        style: GoogleFonts.inter(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(email,
                        style: GoogleFonts.inter(
                            color: AppTheme.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'ADMIN ROLE',
                        style: GoogleFonts.inter(
                          color: AppTheme.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                onPressed: () => _confirmDeleteAdmin(context, admin['id'] as String, email),
              ),
            ],
          ),
        );
  }

  void _confirmDeleteAdmin(BuildContext context, String adminId, String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Text('Delete Admin', style: GoogleFonts.inter(color: AppTheme.textPrimary)),
        content: Text('Are you sure you want to delete the admin account for $email? They will lose access to the system.',
            style: GoogleFonts.inter(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _loading = true);
              try {
                await Supabase.instance.client
                    .from('user_roles')
                    .delete()
                    .eq('user_id', adminId);
                _load();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Admin access revoked successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
                  );
                }
              } finally {
                setState(() => _loading = false);
              }
            },
            child: Text('Delete', style: GoogleFonts.inter(color: AppTheme.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext ctx, AppProvider provider, Map<String, dynamic> rec) {
    final nameCtrl = TextEditingController(text: rec['name'] as String?);
    final phoneCtrl = TextEditingController(text: rec['phone'] as String? ?? '');
    final natCtrl = TextEditingController(text: rec['nationality'] as String? ?? '');

    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Profile',
            style: GoogleFonts.inter(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline, color: AppTheme.textMuted),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: natCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Nationality',
                prefixIcon: Icon(Icons.flag_outlined, color: AppTheme.textMuted),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.textMuted),
              ),
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
              final newName = nameCtrl.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(dialogCtx);
              try {
                await StaffService().update(rec['id'] as String, {
                  'name': newName,
                  'nationality': natCtrl.text.trim().isEmpty ? 'Unknown' : natCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                });
                await provider.init();
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Error updating profile: $e')),
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

  Widget _buildStaffMyInfo(AppProvider provider) {
    final rec = provider.myStaffRecord;
    if (rec == null) {
      return const Center(child: CircularProgressIndicator());
    }

    String? locationText;
    String? roomText;
    String? bedText;

    final assignments = rec['bed_assignments'] as List?;
    if (assignments != null && assignments.isNotEmpty) {
      final bed = assignments.first['bed'] as Map<String, dynamic>?;
      if (bed != null) {
        bedText = "${bed['bed_code']} (${bed['position']})";
        final room = bed['room'] as Map<String, dynamic>?;
        if (room != null) {
          roomText = "${room['room_number']} (${room['room_code']})";
          final location = room['location'] as Map<String, dynamic>?;
          if (location != null) {
            locationText = "${location['name']} (${location['id']})";
          }
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF4C1D95)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  _getInitials(rec['name'] as String?),
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(rec['name'] as String? ?? '',
                style: GoogleFonts.inter(
                    color: Colors.black87,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text('ID: ${rec['staff_id'] ?? ''}',
                style: GoogleFonts.inter(
                    color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 32),
          Text('Personal Details',
              style: GoogleFonts.inter(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _infoTile(Icons.badge_outlined, 'Occupant ID', rec['staff_id'] ?? '-'),
          _infoTile(Icons.circle, 'Status', rec['status'] ?? '-'),
          if (locationText != null)
            _infoTile(Icons.location_on_outlined, 'Accommodation Location', locationText),
          if (roomText != null)
            _infoTile(Icons.meeting_room_outlined, 'Room', roomText),
          if (bedText != null)
            _infoTile(Icons.bed_outlined, 'Bed Assignment', bedText),
          if (rec['phone'] != null)
            _infoTile(Icons.phone_outlined, 'Phone', rec['phone']),
          if (rec['nationality'] != null)
            _infoTile(Icons.flag_outlined, 'Nationality', rec['nationality']),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _showEditProfileDialog(context, provider, rec),
              icon: const Icon(Icons.edit, size: 20),
              label: const Text('Edit Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF8B5CF6),
                side: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(' ').where((w) => w.isNotEmpty).take(2);
    if (parts.isEmpty) return '?';
    return parts.map((w) => w[0].toUpperCase()).join();
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF8B5CF6), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    style: GoogleFonts.inter(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyRequestsTab() {
    final pending = _myPending;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (pending.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pending_actions_outlined,
                size: 56, color: Colors.black26),
            const SizedBox(height: 12),
            Text('No requests yet',
                style: GoogleFonts.inter(
                    color: Colors.black87, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Use the Leave or Shifts page to submit requests',
                style: GoogleFonts.inter(
                    color: Colors.black54, fontSize: 13)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: pending.length,
      itemBuilder: (ctx, i) => _PendingMiniCard(change: pending[i]),
    );
  }

  void _showAddStaffDialog(BuildContext ctx, AppProvider provider) {
    final staffIdCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final natCtrl = TextEditingController();

    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Staff Member',
            style: GoogleFonts.inter(color: Colors.black87)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: staffIdCtrl,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(labelText: 'Staff ID (e.g. 1265)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(labelText: 'Phone (optional)'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: natCtrl,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(labelText: 'Nationality (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (staffIdCtrl.text.isEmpty || nameCtrl.text.isEmpty) return;
              Navigator.pop(dCtx);
              try {
                await StaffService().create(StaffModel(
                  id: '',
                  staffId: staffIdCtrl.text.trim(),
                  name: nameCtrl.text.trim(),
                  status: 'Active',
                  phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                  nationality: natCtrl.text.trim().isEmpty ? null : natCtrl.text.trim(),
                ));
                _load();
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _PendingMiniCard extends StatelessWidget {
  final PendingChange change;
  const _PendingMiniCard({required this.change});

  Color get _color {
    switch (change.status) {
      case 'approved': return const Color(0xFF10B981); // Green
      case 'rejected': return const Color(0xFFEF4444); // Red
      default: return const Color(0xFFF59E0B); // Amber
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = change.changeType == 'leave_request'
        ? 'Leave Request'
        : change.changeType == 'shift_request'
            ? 'Room Shift'
            : change.changeType;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              change.changeType == 'leave_request' ? Icons.beach_access : Icons.swap_horiz,
              color: _color,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(change.createdAt.toString().substring(0, 10),
                    style: GoogleFonts.inter(
                        color: Colors.black54, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
                change.changeType == 'shift_request' && change.status == 'pending_arrival'
                    ? 'ADMIN APPROVED, PROCEED'
                    : change.status.toUpperCase(),
                style: GoogleFonts.inter(
                    color: _color, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  final StaffModel staff;
  final bool isAdmin;
  final int pendingCount;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  const _StaffCard({
    required this.staff,
    required this.isAdmin,
    required this.pendingCount,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    String getInitials(String name) {
      if (name.trim().isEmpty) return '?';
      final parts = name.trim().split(' ').where((w) => w.isNotEmpty).take(2);
      if (parts.isEmpty) return '?';
      return parts.map((w) => w[0].toUpperCase()).join();
    }
    final initials = getInitials(staff.name);

    // Determine live status
    bool isActive = staff.currentBedCode != null;
    bool isOnLeave = staff.status == 'On Leave';
    
    Color dotColor = Colors.grey;
    if (isOnLeave) {
      dotColor = AppTheme.warning; // Orange
    } else if (isActive) {
      dotColor = AppTheme.success; // Green
    }

    String locationDisplay = "Not Assigned";
    if (staff.currentLocationName != null && staff.currentBedCode != null) {
      locationDisplay = "${staff.currentLocationName}  •  Bed ${staff.currentBedCode}";
    }

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
              color: AppTheme.primary.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Row(
          children: [
            // Avatar with live status dot
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(initials,
                        style: GoogleFonts.inter(
                            color: AppTheme.primary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(staff.name,
                      style: GoogleFonts.inter(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('ID: ${staff.staffId}',
                      style: GoogleFonts.inter(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.business, color: AppTheme.primary, size: 14),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              "${staff.currentLocationName} • Bed ${staff.currentBedCode}",
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: AppTheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.info_outline, color: Colors.black54, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            staff.status,
                            style: GoogleFonts.inter(
                              color: Colors.black54,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // More options
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (pendingCount > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$pendingCount pending',
                      style: GoogleFonts.inter(
                          color: AppTheme.warning,
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                if (isAdmin && onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppTheme.bgCard,
                          title: const Text('Delete Staff'),
                          content: Text('Are you sure you want to delete ${staff.name}?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                              onPressed: () {
                                Navigator.pop(ctx);
                                onDelete!();
                              },
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                else
                  const Icon(Icons.more_vert, color: Colors.black38),
              ],
            ),
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

class _EmptyStaff extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyStaff({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, color: AppTheme.textMuted, size: 56),
          const SizedBox(height: 16),
          Text('No staff found',
              style: GoogleFonts.inter(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Tap the + icon to add staff members',
              style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}
