import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';
import '../../widgets/loading_skeleton.dart';

class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _complaints = [];
  final _client = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final provider = context.read<AppProvider>();
    try {
      if (provider.isAdmin) {
        // Admins see all complaints
        final res = await _client
            .from('complaints')
            .select('*, staff:staff_id(name, staff_id)')
            .order('created_at', ascending: false);
        _complaints = List<Map<String, dynamic>>.from(res);
      } else {
        // Staff/Supervisor see their own complaints
        final staffId = provider.myStaffRecord?['id'];
        if (staffId != null) {
          final res = await _client
              .from('complaints')
              .select('*')
              .eq('staff_id', staffId)
              .order('created_at', ascending: false);
          _complaints = List<Map<String, dynamic>>.from(res);
        }
      }
    } catch (e) {
      debugPrint('Error loading complaints: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isAdmin = provider.isAdmin;
    final isStaff = provider.isStaff || provider.isSupervisor;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 16,
                    bottom: 24,
                    left: 20,
                    right: 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF4C1D95)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Complaints & Reports',
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              // List
              Expanded(
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                            children: [SkeletonCard(), SkeletonCard()]),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: _complaints.isEmpty
                            ? ListView(
                                padding: const EdgeInsets.all(20),
                                children: [
                                  const SizedBox(height: 100),
                                  Center(
                                    child: Column(
                                      children: [
                                        Icon(Icons.check_circle_outline,
                                            size: 64,
                                            color: Colors.black26),
                                        const SizedBox(height: 16),
                                        Text('No Complaints Found',
                                            style: GoogleFonts.inter(
                                                color: Colors.black87,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  )
                                ],
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(20),
                                itemCount: _complaints.length,
                                itemBuilder: (context, index) {
                                  final complaint = _complaints[index];
                                  final dateStr = complaint['created_at'];
                                  final date = DateTime.tryParse(dateStr ?? '') ??
                                      DateTime.now();
                                  final dateFormatted =
                                      '${date.day}/${date.month}/${date.year}';
                                  
                                  final staffName = complaint['staff']?['name'];

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
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
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              dateFormatted,
                                              style: GoogleFonts.inter(
                                                  color: Colors.black54,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500),
                                            ),
                                            if (isAdmin && staffName != null)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.primary
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  staffName,
                                                  style: GoogleFonts.inter(
                                                      color: AppTheme.primary,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          complaint['description'] ?? '',
                                          style: GoogleFonts.inter(
                                              color: Colors.black87,
                                              fontSize: 14,
                                              height: 1.5),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
              ),
            ],
          ),
          if (isStaff)
            Positioned(
              right: 16,
              bottom: 110,
              child: FloatingActionButton.extended(
                onPressed: () => _showAddComplaintDialog(context, provider),
                backgroundColor: AppTheme.primary,
                icon: const Icon(Icons.add_comment_rounded, color: Colors.white),
                label: Text('Raise Complaint',
                    style: GoogleFonts.inter(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAddComplaintDialog(
      BuildContext context, AppProvider provider) async {
    final staffRecord = provider.myStaffRecord;
    if (staffRecord == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find your staff record.')),
      );
      return;
    }

    final ctrl = TextEditingController();
    bool submitting = false;

    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppTheme.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Raise a Complaint',
                style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Your complaint will be sent securely to the administrators.',
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: ctrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Describe your issue or report...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: submitting
                      ? null
                      : () async {
                          if (ctrl.text.trim().isEmpty) return;
                          setModalState(() => submitting = true);
                          try {
                            await _client.from('complaints').insert({
                              'staff_id': staffRecord['id'],
                              'description': ctrl.text.trim(),
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            debugPrint('Error saving complaint: $e');
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to submit complaint.'),
                                backgroundColor: AppTheme.danger,
                              ),
                            );
                            setModalState(() => submitting = false);
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : Text(
                          'Submit',
                          style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );

    _load();
  }
}
