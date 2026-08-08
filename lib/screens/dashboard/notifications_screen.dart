import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';

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
      final res = await Supabase.instance.client
          .from('app_notifications')
          .select('*')
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
  
  Future<void> _deleteNotification(String id) async {
    try {
      await Supabase.instance.client.from('app_notifications').delete().eq('id', id);
      setState(() {
        _notifications.removeWhere((n) => n['id'] == id);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification deleted')));
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete notification: $e')));
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
                          Text('No new notifications', style: GoogleFonts.inter(color: Colors.black54, fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      itemCount: _notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) {
                        final notif = _notifications[i];
                        final title = notif['title'] ?? 'Notification';
                        final message = notif['message'] ?? '';
                        final type = notif['type'] ?? '';
                        final notifId = notif['id'] as String;
                        final createdAt = notif['created_at'] != null ? DateTime.parse(notif['created_at']) : DateTime.now();
                        
                        final isDeleted = type == 'staff_deleted';
                        final iconData = isDeleted ? Icons.person_remove_alt_1_rounded : Icons.person_add_alt_1_rounded;
                        final iconColor = isDeleted ? AppTheme.danger : AppTheme.accent;

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
                              backgroundColor: iconColor.withValues(alpha: 0.1),
                              child: Icon(iconData, color: iconColor),
                            ),
                            title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF1E293B))),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(message, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatTimeAgo(createdAt),
                                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  onPressed: () => _deleteNotification(notifId),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  splashRadius: 20,
                                ),
                              ],
                            ),
                            isThreeLine: false,
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
