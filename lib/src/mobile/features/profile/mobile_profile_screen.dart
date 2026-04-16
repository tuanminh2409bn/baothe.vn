import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../constants/app_styles.dart';
import '../../../services/auth_service.dart';

class MobileProfileScreen extends ConsumerWidget {
  const MobileProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'TÀI KHOẢN',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.2),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                    style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user?.email ?? 'Người dùng',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Thành viên Premium',
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.textLight),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          _buildMenuTile(Icons.security_rounded, 'Bảo mật tài khoản'),
          _buildMenuTile(Icons.notifications_none_rounded, 'Cài đặt thông báo'),
          _buildMenuTile(Icons.help_outline_rounded, 'Hỗ trợ & Trợ giúp'),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 64,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authServiceProvider).signOut();
                  if (context.mounted) context.go('/login');
                },
                icon: const Icon(Icons.logout_rounded, color: Colors.red),
                label: const Text('ĐĂNG XUẤT', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SafeArea(top: false, child: SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _buildMenuTile(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textPrimary),
      title: Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
      onTap: () {},
    );
  }
}
