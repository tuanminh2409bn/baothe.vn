import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../constants/app_styles.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';

class MobileProfileScreen extends ConsumerWidget {
  const MobileProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authServiceProvider).currentUser;
    final userProfileAsync = authUser != null 
        ? ref.watch(userProfileProvider(authUser.uid))
        : const AsyncValue<Map<String, dynamic>?>.data(null);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'TÀI KHOẢN',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppColors.textPrimary(context)),
        ),
      ),
      body: userProfileAsync.when(
        data: (profile) {
          final displayName = profile?['displayName'] ?? authUser?.displayName ?? authUser?.email?.split('@')[0] ?? 'Người dùng';
          final photoURL = profile?['photoURL'] ?? authUser?.photoURL;
          final email = profile?['email'] ?? authUser?.email ?? '';

          return Column(
            children: [
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.primary(context),
                      backgroundImage: photoURL != null ? NetworkImage(photoURL) : null,
                      child: photoURL == null ? Text(
                        displayName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                      ) : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      displayName,
                      style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context)),
                    ),
                    Text(
                      email,
                      style: GoogleFonts.inter(fontSize: 14, color: AppColors.textLight(context)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary(context).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Thành viên Premium',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary(context), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              _buildMenuTile(context, Icons.security_rounded, 'Bảo mật tài khoản'),
              _buildMenuTile(context, Icons.notifications_none_rounded, 'Cài đặt thông báo'),
              _buildMenuTile(context, Icons.help_outline_rounded, 'Hỗ trợ & Trợ giúp'),
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
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, __) => Center(child: Text('Lỗi tải dữ liệu: $err')),
      ),
    );
  }

  Widget _buildMenuTile(BuildContext context, IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textPrimary(context)),
      title: Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: () {},
    );
  }
}
