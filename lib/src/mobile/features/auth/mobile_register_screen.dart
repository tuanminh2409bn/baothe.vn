import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../constants/app_styles.dart';
import '../../../services/auth_service.dart';

class MobileRegisterScreen extends ConsumerStatefulWidget {
  const MobileRegisterScreen({super.key});

  @override
  ConsumerState<MobileRegisterScreen> createState() => _MobileRegisterScreenState();
}

class _MobileRegisterScreenState extends ConsumerState<MobileRegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showError('Vui lòng điền đầy đủ thông tin');
      return;
    }
    if (password.length < 6) {
      _showError('Mật khẩu phải có ít nhất 6 ký tự');
      return;
    }
    if (password != confirmPassword) {
      _showError('Xác nhận mật khẩu không khớp');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signUp(email, password, fullName: name);
      if (mounted) {
        context.go('/'); 
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final cred = await authService.signInWithGoogle();
      if (cred != null && mounted) {
        context.go('/');
      }
    } catch (e) {
      if (e.toString().toLowerCase().contains('canceled')) return;
      _showError('Đăng nhập Google thất bại: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final cred = await authService.signInWithApple();
      if (cred != null && mounted) {
        context.go('/');
      }
    } catch (e) {
      if (e.toString().toLowerCase().contains('canceled')) return;
      _showError('Đăng nhập Apple thất bại: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFFFF), Color(0xFFF3F4F6), Color(0xFFE5E7EB)],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/login');
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Logo
                  Center(
                    child: Image.asset(
                      'assets/logo/logo_app.png',
                      height: 80,
                    ).animate().fadeIn(duration: 800.ms).scale(delay: 200.ms),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Tạo tài khoản mới',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 30),

                  // Register Form
                  _buildInputField(
                    controller: _nameController,
                    label: 'Họ và tên',
                    icon: Icons.person_outline_rounded,
                  ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.email_outlined,
                  ).animate().fadeIn(delay: 450.ms).slideX(begin: 0.1),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _passwordController,
                    label: 'Mật khẩu',
                    icon: Icons.lock_outline_rounded,
                    isPassword: true,
                    isVisible: _isPasswordVisible,
                    onVisibilityChanged: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.1),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _confirmPasswordController,
                    label: 'Xác nhận mật khẩu',
                    icon: Icons.lock_outline_rounded,
                    isPassword: true,
                    isVisible: _isConfirmPasswordVisible,
                    onVisibilityChanged: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                  ).animate().fadeIn(delay: 550.ms).slideX(begin: 0.1),
                  
                  const SizedBox(height: 32),
                  
                  // Register Button
                  _buildPrimaryButton(
                    label: 'ĐĂNG KÝ',
                    onPressed: _isLoading ? null : _handleRegister,
                  ).animate().fadeIn(delay: 600.ms).scale(),
                  
                  const SizedBox(height: 32),
                  
                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Đăng ký bằng mạng xã hội', style: GoogleFonts.inter(color: AppColors.textLight, fontSize: 13)),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                    ],
                  ).animate().fadeIn(delay: 700.ms),
                  
                  const SizedBox(height: 24),
                  
                  // Social Register Buttons
                  _SocialLoginButton(
                    customIcon: Image.asset('assets/logo/google_logo.png', height: 24),
                    label: 'Tiếp tục với Google',
                    onPressed: _isLoading ? () {} : _handleGoogleSignIn,
                  ).animate().fadeIn(delay: 750.ms).slideY(begin: 0.1),
                  
                  if (isIOS) ...[
                    const SizedBox(height: 16),
                    _SocialLoginButton(
                      icon: FontAwesomeIcons.apple,
                      label: 'Tiếp tục với Apple',
                      onPressed: _isLoading ? () {} : _handleAppleSignIn,
                    ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.1),
                  ],
                  
                  const SizedBox(height: 30),
                  
                  // Footer -> go to login
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Đã có tài khoản?',
                        style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14),
                      ),
                      TextButton(
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/login');
                          }
                        },
                        child: Text(
                          'Đăng nhập',
                          style: GoogleFonts.inter(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 900.ms),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool isVisible = false,
    VoidCallback? onVisibilityChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && !isVisible,
        decoration: InputDecoration(
          icon: Icon(icon, color: AppColors.textLight, size: 20),
          labelText: label,
          labelStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
          border: InputBorder.none,
          suffixIcon: isPassword 
            ? IconButton(
                icon: Icon(isVisible ? Icons.visibility_off : Icons.visibility, color: AppColors.textLight, size: 20),
                onPressed: onVisibilityChanged,
              )
            : null,
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({required String label, required VoidCallback? onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          shadowColor: AppColors.primary.withValues(alpha: 0.3),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }
}

class _SocialLoginButton extends StatelessWidget {
  final dynamic icon;
  final Widget? customIcon;
  final String label;
  final VoidCallback onPressed;

  const _SocialLoginButton({this.icon, this.customIcon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ?customIcon,
            if (icon != null) ...[
              if (icon is IconData)
                Icon(icon as IconData, size: 20)
              else
                FaIcon(icon, size: 20),
            ],
            const SizedBox(width: 12),
            Text(label, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
