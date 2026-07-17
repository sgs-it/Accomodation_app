import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../providers/app_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Fetch staff added in the last 7 days, ordered by created_at DESC
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
      final res = await Supabase.instance.client
          .from('staff')
          .select('*, bed_assignments(bed:beds(id, bed_code, room:rooms(location:locations(name))))')
          .gte('created_at', sevenDaysAgo)
          .order('created_at', ascending: false)
          .limit(50);
          
      setState(() {
        _notifications = List<Map<String, dynamic>>.from(res);
      });
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    } finally {
      setState(() => _loading = false);
    }
  }
  
  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B5CF6),
        title: Text('Notifications', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          Text('No new staff added recently', style: GoogleFonts.inter(color: Colors.black54, fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      itemCount: _notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) {
                        final notif = _notifications[i];
                        final name = notif['name'] ?? 'Unknown';
                        final staffId = notif['staff_id'] ?? 'N/A';
                        final createdAt = notif['created_at'] != null ? DateTime.parse(notif['created_at']) : DateTime.now();
                        
                        // Parse bed info if assigned
                        String assignmentText = "Not assigned to a bed";
                        final assignments = notif['bed_assignments'] as List?;
                        if (assignments != null && assignments.isNotEmpty) {
                           final bed = assignments.first['bed'];
                           if (bed != null) {
                             final locName = bed['room']?['location']?['name'] ?? 'Unknown Loc';
                             assignmentText = "Assigned to Bed ${bed['bed_code']} in $locName";
                           }
                        }

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.accent.withValues(alpha: 0.1),
                              child: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.accent),
                            ),
                            title: Text('New Staff: $name', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF1E293B))),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text('ID: $staffId', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                                const SizedBox(height: 2),
                                Text(assignmentText, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.primary)),
                              ],
                            ),
                            trailing: Text(
                              _formatTimeAgo(createdAt),
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
