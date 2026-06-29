// lib/screens/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl   = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  // Toggle between Admin (email) and Staff (occupant ID) login
  bool _isStaffLogin = true;

  late final AnimationController _animCtrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _passCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final provider = context.read<AppProvider>();
      await provider.authService.signIn(
        identifier: _idCtrl.text.trim(),
        password:   _passCtrl.text,
      );
      await provider.init();
      if (mounted) context.go('/dashboard');
    } catch (e) {
      setState(() {
        _error = _isStaffLogin
            ? 'Invalid Staff ID or password. Try your Occupant ID and Bed ID.'
            : 'Invalid email or password. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  // Logo
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primary, AppTheme.accent],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.4),
                          blurRadius: 20, offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.home_work_rounded,
                        color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 32),
                  Text('Welcome back',
                      style: GoogleFonts.inter(
                        color: AppTheme.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      )),
                  const SizedBox(height: 8),
                  Text('Staff Accommodation Management',
                      style: GoogleFonts.inter(
                          color: AppTheme.textSecondary, fontSize: 14)),
                  const SizedBox(height: 32),

                  // Login type toggle
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _buildToggle('Staff Login', _isStaffLogin, () {
                          setState(() { _isStaffLogin = true; _idCtrl.clear(); _error = null; });
                        }),
                        _buildToggle('Admin Login', !_isStaffLogin, () {
                          setState(() { _isStaffLogin = false; _idCtrl.clear(); _error = null; });
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ID / Email field
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: TextFormField(
                      key: ValueKey(_isStaffLogin),
                      controller: _idCtrl,
                      keyboardType: _isStaffLogin
                          ? TextInputType.text
                          : TextInputType.emailAddress,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: _isStaffLogin ? 'Occupant ID' : 'Admin Email',
                        hintText: _isStaffLogin ? 'e.g. 1325 or LS6080' : 'admin@example.com',
                        hintStyle: const TextStyle(color: AppTheme.textMuted),
                        prefixIcon: Icon(
                          _isStaffLogin
                              ? Icons.badge_outlined
                              : Icons.email_outlined,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return _isStaffLogin
                              ? 'Enter your Occupant ID'
                              : 'Enter your admin email';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: _isStaffLogin ? 'Your Bed ID (e.g. R2026-053)' : '',
                      hintStyle: const TextStyle(color: AppTheme.textMuted),
                      prefixIcon: const Icon(Icons.lock_outline,
                          color: AppTheme.textMuted),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                          color: AppTheme.textMuted,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Enter your password' : null,
                  ),
                  const SizedBox(height: 24),

                  // Error
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.danger.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppTheme.danger, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: GoogleFonts.inter(
                                    color: AppTheme.danger, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),

                  // Sign In button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _signIn,
                      child: _loading
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_isStaffLogin ? 'Sign In as Staff' : 'Sign In as Admin'),
                    ),
                  ),

                  if (_isStaffLogin) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: AppTheme.primary, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Username: Your Occupant ID  •  Password: Your Bed ID',
                              style: GoogleFonts.inter(
                                  color: AppTheme.primary, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),
                  Center(
                    child: Text(
                      'Staff Accommodation Management System',
                      style: GoogleFonts.inter(
                          color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggle(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: active ? Colors.white : AppTheme.textMuted,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
