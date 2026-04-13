import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../constants/app_styles.dart';
import '../../../services/auth_service.dart';

class MobileLoginScreen extends ConsumerStatefulWidget {
  const MobileLoginScreen({super.key});

  @override
  ConsumerState<MobileLoginScreen> createState() => _MobileLoginScreenState();
}

class _MobileLoginScreenState extends ConsumerState<MobileLoginScreen> {
  bool _isLoading = false;

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
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
          // 1. Animated Card Background
          const Positioned.fill(
            child: _AnimatedCardBackground(),
          ),
          
          // 2. Gradient Overlay to make text and buttons readable
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.2, 0.5, 1.0],
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.1),
                    Colors.white.withValues(alpha: 0.85),
                    Colors.white,
                  ],
                ),
              ),
            ),
          ),
          
          // 3. Foreground Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(),
                  
                  // Logo
                  Image.asset(
                    'assets/logo/logo_login.png',
                    height: 80,
                  ).animate().fadeIn(duration: 800.ms).scale(delay: 200.ms),
                  
                  const SizedBox(height: 24),
                  
                  // Title
                  Text(
                    'So Sánh & Quản Lý\nThẻ Tín Dụng',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
                  
                  const SizedBox(height: 12),
                  
                  // Subtitle
                  Text(
                    'Tìm thẻ tốt nhất và tối ưu hóa chi tiêu của bạn.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),
                  
                  const SizedBox(height: 40),
                  
                  // Social Login Buttons
                  if (isIOS) ...[
                    _LoginButton(
                      icon: FontAwesomeIcons.apple,
                      label: 'Tiếp tục với Apple',
                      backgroundColor: Colors.black,
                      textColor: Colors.white,
                      onPressed: _isLoading ? () {} : _handleAppleSignIn,
                    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1),
                    const SizedBox(height: 16),
                  ],
                  
                  _LoginButton(
                    customIcon: Image.asset('assets/logo/google_logo.png', height: 24),
                    label: 'Tiếp tục với Google',
                    backgroundColor: Colors.white,
                    textColor: AppColors.textPrimary,
                    borderColor: const Color(0xFFE5E7EB),
                    onPressed: _isLoading ? () {} : _handleGoogleSignIn,
                  ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.1),
                  
                  const SizedBox(height: 16),
                  
                  _LoginButton(
                    icon: Icons.email_outlined,
                    label: 'Tiếp tục với Email',
                    backgroundColor: AppColors.primary,
                    textColor: Colors.white,
                    onPressed: () => context.push('/login-email'),
                  ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.1),
                  
                  const SizedBox(height: 24),
                  
                  // Footer
                  TextButton(
                    onPressed: () => context.push('/register'),
                    child: RichText(
                      text: TextSpan(
                        text: 'Chưa có tài khoản? ',
                        style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14),
                        children: [
                          TextSpan(
                            text: 'Đăng ký ngay',
                            style: GoogleFonts.inter(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 900.ms),
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
}

class _LoginButton extends StatelessWidget {
  final IconData? icon;
  final Widget? customIcon;
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final VoidCallback onPressed;

  const _LoginButton({
    this.icon,
    this.customIcon,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: borderColor != null ? BorderSide(color: borderColor!, width: 1.5) : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (customIcon != null) customIcon!,
            if (icon != null) Icon(icon, size: 24, color: textColor),
            const SizedBox(width: 12),
            Text(label, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
          ],
        ),
      ),
    );
  }
}

// --- Background Animation Components ---

class _AnimatedCardBackground extends StatefulWidget {
  const _AnimatedCardBackground();

  @override
  State<_AnimatedCardBackground> createState() => _AnimatedCardBackgroundState();
}

class _AnimatedCardBackgroundState extends State<_AnimatedCardBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 30 seconds for a full loop of scrolling
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;
            // The total height of our list is roughly 1500, we scroll from 0 to 1500.
            // Using Fractional offset or a direct translation.
            final scrollOffset = _controller.value * 2000.0;

            final colWidth = (constraints.maxWidth - 32) / 3;
            
            return Stack(
              children: [
                // Column 1 (Left) - moves up normal speed
                Positioned(
                  left: 0,
                  top: -scrollOffset,
                  child: _CardColumn(
                    seed: 1,
                    cardCount: 20,
                    width: colWidth,
                  ),
                ),
                // Column 2 (Center) - moves up slightly faster, offset starts differently
                Positioned(
                  left: colWidth + 16,
                  top: -(scrollOffset * 1.2) - 100, // Starts a bit higher and moves faster
                  child: _CardColumn(
                    seed: 2,
                    cardCount: 25,
                    width: colWidth,
                  ),
                ),
                // Column 3 (Right) - moves up slightly slower
                Positioned(
                  left: (colWidth * 2) + 32,
                  top: -(scrollOffset * 0.8),
                  child: _CardColumn(
                    seed: 3,
                    cardCount: 20,
                    width: colWidth,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CardColumn extends StatelessWidget {
  final int seed;
  final int cardCount;
  final double width;

  const _CardColumn({required this.seed, required this.cardCount, required this.width});

  @override
  Widget build(BuildContext context) {
    final rng = _SimpleRNG(seed);
    
    final List<String> cardImages = [
      'acb_the_acb_express.png',
      'acb_the_acb_jcb_gold.png',
      'acb_the_acb_visa_platinum.png',
      'acb_the_acb_visa_signature.png',
      'bidv_the_bidv_jcb_ultimate.png',
      'bidv_the_bidv_jcb_well_being.png',
      'bidv_the_bidv_mastercard_world_travel.png',
      'bidv_the_bidv_visa_cashback_360.png',
      'bidv_the_bidv_visa_cashback_online.png',
      'bidv_the_bidv_visa_easy.png',
      'bidv_the_bidv_visa_flexi.png',
      'bidv_the_bidv_visa_flexi_sao_vang.png',
      'bidv_the_bidv_visa_infinite.png',
    ];
    
    // We create a very long column of cards so it doesn't run out during the animation
    return Column(
      children: List.generate(cardCount, (index) {
        final imageName = cardImages[rng.nextInt(cardImages.length)];
        final imageUrl = 'https://storage.googleapis.com/baothevn-790c6.firebasestorage.app/card_images/$imageName';
        
        // Typical credit card ratio is around 1.58.
        // For a vertical display, height is width * 1.58.
        final cardHeight = width * 1.58;
        
        return Container(
          width: width,
          height: cardHeight,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (context, url) => Container(
                color: Colors.grey.shade200,
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey.shade300,
                child: const Icon(Icons.credit_card, color: Colors.grey),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// A simple pseudo-random number generator for deterministic randomness without dart:math
class _SimpleRNG {
  int _state;
  _SimpleRNG(this._state);

  int nextInt(int max) {
    _state = (_state * 1103515245 + 12345) & 0x7fffffff;
    return _state % max;
  }
}
