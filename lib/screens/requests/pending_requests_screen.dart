// lib/screens/requests/pending_requests_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';
import '../../services/pending_service.dart';

class PendingRequestsScreen extends StatefulWidget {
  const PendingRequestsScreen({super.key});

  @override
  State<PendingRequestsScreen> createState() => _PendingRequestsScreenState();
}

class _PendingRequestsScreenState extends State<PendingRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    await context.read<AppProvider>().loadPendingChanges();
    setState(() => _loading = false);
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
                      Expanded(
                        child: Text(
                          'Pending Requests',
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
                controller: _tabs,
                indicatorColor: const Color(0xFF8B5CF6),
                labelColor: const Color(0xFF8B5CF6),
                unselectedLabelColor: Colors.black54,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: const [
                  Tab(text: 'Pending'),
                  Tab(text: 'Approved'),
                  Tab(text: 'Rejected'),
                ],
              ),
            ),
          ),

          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -10),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabs,
                      children: const [
                        _RequestsList(status: 'pending'),
                        _RequestsList(status: 'approved'),
                        _RequestsList(status: 'rejected'),
                      ],
                    ),
            ),
          ),
        ],
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

class _RequestsList extends StatelessWidget {
  final String status;
  const _RequestsList({required this.status});

  @override
  Widget build(BuildContext context) {
    final all = context.watch<AppProvider>().pendingChanges;
    final list = all.where((c) {
      if (status == 'pending') {
        return c.status == 'pending' || c.status == 'pending_supervisor' || c.status == 'pending_arrival';
      }
      return c.status == status;
    }).toList();

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 64, color: AppTheme.textMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text('No $status requests',
                style: GoogleFonts.inter(color: AppTheme.textMuted)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: Colors.white,
      onRefresh: () => context.read<AppProvider>().loadPendingChanges(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
        itemCount: list.length,
        itemBuilder: (ctx, i) => _RequestCard(change: list[i]),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final PendingChange change;
  const _RequestCard({required this.change});

  Color get _statusColor {
    switch (change.status) {
      case 'approved': return AppTheme.success;
      case 'rejected': return AppTheme.danger;
      default:         return AppTheme.warning;
    }
  }

  IconData get _typeIcon {
    switch (change.changeType) {
      case 'shift_request':  return Icons.swap_horiz_rounded;
      case 'profile_edit':   return Icons.edit_rounded;
      case 'new_entry':      return Icons.add_circle_outline;
      case 'status_change':  return Icons.sync_rounded;
      default:               return Icons.pending_actions_rounded;
    }
  }

  String get _typeLabel {
    switch (change.changeType) {
      case 'shift_request': return 'Room Shift Request';
      case 'leave_request':
        final lType = change.payload['leave_type'] as String?;
        return lType != null ? '$lType Request' : 'Leave Request';
      case 'profile_edit':  return 'Profile Edit';
      case 'new_entry':     return 'New Data Entry';
      case 'status_change': return 'Status Change';
      default: return change.changeType.replaceAll('_', ' ').toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: _statusColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(_typeIcon, color: _statusColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_typeLabel,
                      style: GoogleFonts.inter(
                          color: _statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(change.status.replaceAll('_', ' ').toUpperCase(),
                      style: GoogleFonts.inter(
                          color: _statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
                if ((change.status == 'approved' || change.status == 'rejected') && provider.isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: InkWell(
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: Colors.white,
                            title: const Text('Delete Request'),
                            content: const Text('Are you sure you want to permanently delete this request?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          try {
                            await provider.pendingService.deleteRequest(change.id);
                            await provider.loadPendingChanges();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        }
                      },
                      child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    ),
                  ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.person_outline,
                      size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 6),
                  Text('Submitted by: ',
                      style: GoogleFonts.inter(
                          color: AppTheme.textMuted, fontSize: 12)),
                  Text(change.staffName,
                      style: GoogleFonts.inter(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ]),
                const SizedBox(height: 8),

                // Payload details
                ...change.payload.entries
                  .where((e) => e.key != 'staff_name' && e.key != 'staff_id' && e.key != 'past_sick_leaves_this_year' && e.key != 'leave_type' && !e.key.endsWith('_id'))
                  .map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${_prettify(e.key)}: ',
                              style: GoogleFonts.inter(
                                  color: Colors.black54, fontSize: 12)),
                          Expanded(
                            child: Text(e.value.toString(),
                                style: GoogleFonts.inter(
                                    color: Colors.black87,
                                    fontSize: 12)),
                          ),
                        ],
                      ),
                    )),
                    
                // Special rendering for Sick Leave
                if (change.changeType == 'leave_request' && change.payload['leave_type'] == 'Sick Leave') ...[
                  const SizedBox(height: 8),
                  Builder(
                    builder: (ctx) {
                      final past = (change.payload['past_sick_leaves_this_year'] as num?)?.toInt() ?? 0;
                      // Include this current request in the total requested times
                      final totalTimes = past + 1;
                      final isOverLimit = totalTimes > 12;

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isOverLimit ? AppTheme.danger.withValues(alpha: 0.1) : AppTheme.bgDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isOverLimit ? AppTheme.danger.withValues(alpha: 0.3) : AppTheme.divider),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sick Leave Times (This Year): $totalTimes / 12',
                              style: GoogleFonts.inter(
                                color: isOverLimit ? AppTheme.danger : AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            if (isOverLimit)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Sick leave finished and salary will be deducted.',
                                  style: GoogleFonts.inter(
                                    color: AppTheme.danger,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],

                if (change.adminNote != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Note: ${change.adminNote}',
                        style: GoogleFonts.inter(
                            color: Colors.black54,
                            fontSize: 12,
                            fontStyle: FontStyle.italic)),
                  ),
                ],

                const SizedBox(height: 12),
                if (provider.isAdmin || provider.isSupervisor) ...[
                  // Comments list
                  if (change.comments.isNotEmpty) ...[
                    Text('Comments:', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
                    const SizedBox(height: 6),
                    ...change.comments.map((c) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.bgDark,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(c['author'] ?? 'Unknown', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 11, color: AppTheme.textPrimary)),
                              Text(_formatDate(DateTime.tryParse(c['date'] ?? '') ?? DateTime.now()), style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(c['text'] ?? '', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      ),
                    )),
                    const SizedBox(height: 8),
                  ],
                  // Add comment button
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _showCommentDialog(context, provider),
                      icon: const Icon(Icons.add_comment_outlined, size: 16),
                      label: Text('Add Comment', style: GoogleFonts.inter(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 6),
                Text(
                  _formatDate(change.createdAt),
                  style: GoogleFonts.inter(
                      color: Colors.black45, fontSize: 11),
                ),
              ],
            ),
          ),

          // Admin and Supervisor action buttons
          Builder(builder: (ctx) {
            final isTargetSupervisor = provider.isSupervisor && change.payload['target_location_id'] == provider.supervisorLocationId;
            final canSupervisorApprove = change.status == 'pending_supervisor' && isTargetSupervisor;
            final canAdminApprove = change.status == 'pending' && provider.isAdmin;
            final canSupervisorConfirm = change.status == 'pending_arrival' && isTargetSupervisor;

            if (canSupervisorApprove || canAdminApprove || canSupervisorConfirm) {
              return Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _reject(context, provider),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.danger,
                          side: const BorderSide(color: AppTheme.danger),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (canSupervisorApprove) {
                            _advance(context, provider, 'pending', 'Approve Request');
                          } else if (canAdminApprove) {
                            _advance(context, provider, change.changeType == 'shift_request' ? 'pending_arrival' : 'approved', 'Approve Request');
                          } else if (canSupervisorConfirm) {
                            _advance(context, provider, 'approved', 'Confirm Arrival');
                          }
                        },
                        icon: const Icon(Icons.check, size: 16),
                        label: Text(canSupervisorConfirm ? 'Confirm' : 'Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  Future<void> _advance(BuildContext context, AppProvider provider, String nextStatus, String title) async {
    final noteCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Text(title,
            style: GoogleFonts.inter(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(nextStatus == 'approved' ? 'This will apply the change immediately.' : 'This will move the request to the next step.',
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'Add a comment...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await provider.advanceStatus(change, nextStatus,
          note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
    }
  }

  Future<void> _showCommentDialog(BuildContext context, AppProvider provider) async {
    final textCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Text('Add Comment',
            style: GoogleFonts.inter(color: AppTheme.textPrimary)),
        content: TextField(
          controller: textCtrl,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Your comment',
            hintText: 'Type something...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary),
            child: const Text('Post'),
          ),
        ],
      ),
    );
    if (confirm == true && textCtrl.text.trim().isNotEmpty && context.mounted) {
      final authorName = provider.isAdmin ? 'Admin' : 'Supervisor';
      await provider.pendingService.addComment(change, authorName, textCtrl.text.trim());
      await provider.loadPendingChanges();
    }
  }

  Future<void> _reject(BuildContext context, AppProvider provider) async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Text('Reject Request',
            style: GoogleFonts.inter(color: AppTheme.textPrimary)),
        content: TextField(
          controller: reasonCtrl,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
            hintText: 'Enter reason...',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await provider.rejectChange(change,
          reason: reasonCtrl.text.trim().isEmpty
              ? 'No reason provided'
              : reasonCtrl.text.trim());
    }
  }

  String _prettify(String key) =>
      key.replaceAll('_', ' ').split(' ').map((w) =>
          w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

  Future<void> _deleteRequest(BuildContext context, AppProvider provider, PendingChange change) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Text('Delete Request',
            style: GoogleFonts.inter(color: AppTheme.textPrimary)),
        content: Text('Are you sure you want to permanently delete this request?',
            style: GoogleFonts.inter(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await provider.pendingService.deleteRequest(change.id);
      await provider.loadPendingChanges();
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
