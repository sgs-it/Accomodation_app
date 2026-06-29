// lib/screens/users/users_screen.dart  (Admin only)

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _staffIdCtrl = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _nameCtrl    = TextEditingController();
  String _selectedRole = 'staff';
  bool _loading = false;
  String? _message;

  @override
  void dispose() {
    _staffIdCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    final id   = _staffIdCtrl.text.trim();
    final pass = _passCtrl.text;
    final name = _nameCtrl.text.trim();
    if (id.isEmpty || pass.isEmpty || name.isEmpty) return;
    
    if (_selectedRole == 'admin' && !id.contains('@')) {
      setState(() => _message = '✗ Admin accounts must use a valid email address.');
      return;
    }

    setState(() { _loading = true; _message = null; });
    try {
      final provider = context.read<AppProvider>();
      await provider.authService.createAccount(
        identifier:  id,
        displayName: name,
        password:    pass,
        role:        _selectedRole,
      );
      setState(() {
        _message = '✓ $_selectedRole account created for $name ($id)';
        _staffIdCtrl.clear();
        _passCtrl.clear();
        _nameCtrl.clear();
      });
    } catch (e) {
      setState(() => _message = '✗ Error: $e');
    } finally {
      setState(() => _loading = false);
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
        title: Text('Create Account',
            style: GoogleFonts.inter(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Staff accounts are usually created automatically via bulk import. '
                      'Use this form to manually create accounts for staff or other admins.',
                      style: GoogleFonts.inter(
                          color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            Text('New Account',
                style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),

            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline, color: AppTheme.textMuted),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _selectedRole,
              dropdownColor: AppTheme.bgCard,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Account Role',
                prefixIcon: Icon(Icons.admin_panel_settings_outlined, color: AppTheme.textMuted),
              ),
              items: const [
                DropdownMenuItem(value: 'staff', child: Text('Staff Member')),
                DropdownMenuItem(value: 'admin', child: Text('Administrator')),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _selectedRole = v;
                    _staffIdCtrl.clear();
                  });
                }
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _staffIdCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: _selectedRole == 'admin' 
                    ? 'Email Address (login username)' 
                    : 'Occupant ID (login username)',
                hintText: _selectedRole == 'admin' 
                    ? 'e.g. admin@sgs.com' 
                    : 'e.g. 1325 or LS6080',
                prefixIcon: const Icon(Icons.badge_outlined, color: AppTheme.textMuted),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: _selectedRole == 'admin'
                    ? 'Password'
                    : 'Default Password (use their Bed ID)',
                hintText: _selectedRole == 'admin'
                    ? 'Minimum 6 characters'
                    : 'e.g. R2026-053',
                prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textMuted),
              ),
            ),
            const SizedBox(height: 24),

            if (_message != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _message!.startsWith('✓')
                      ? AppTheme.success.withValues(alpha: 0.1)
                      : AppTheme.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _message!.startsWith('✓')
                          ? AppTheme.success.withValues(alpha: 0.3)
                          : AppTheme.danger.withValues(alpha: 0.3)),
                ),
                child: Text(_message!,
                    style: GoogleFonts.inter(
                        color: _message!.startsWith('✓')
                            ? AppTheme.success
                            : AppTheme.danger,
                        fontSize: 13)),
              ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _createAccount,
                icon: _loading
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.person_add_rounded),
                label: const Text('Create Account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
