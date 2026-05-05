import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_styles.dart';
import 'features/ai_assistant/finy_ai_floating_button.dart';

class MobileMainLayout extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MobileMainLayout({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: navigationShell,
          floatingActionButton: _buildAddFab(context),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: _buildBottomNav(context),
        ),
        // Finy AI Assistant Floating Button
        Positioned(
          right: 0,
          bottom: Theme.of(context).platform == TargetPlatform.android ? 120 : 100, // Hạ thấp xuống cùng với bottom nav
          child: const FinyAIFloatingButton(),
        ),
      ],
    );
  }

  Widget _buildAddFab(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'main_add_fab',
      onPressed: () => _showAddTransactionOptions(context),
      backgroundColor: AppColors.primary(context),
      shape: const CircleBorder(),
      child: const Icon(Icons.add, color: Colors.white, size: 30),
    ); // Thêm animation sau nếu cần
  }

  void _showAddTransactionOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'BẠN MUỐN THÊM CHI TIÊU VÀO ĐÂU?',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 24),
            _buildOptionCard(
              context,
              icon: Icons.credit_card_rounded,
              title: 'Thêm vào Thẻ tín dụng',
              subtitle: 'Ghi nhận giao dịch quẹt thẻ',
              color: AppColors.primary(context),
              onTap: () {
                Navigator.pop(context);
                context.push('/add-transaction', extra: 'credit');
              },
            ),
            const SizedBox(height: 16),
            _buildOptionCard(
              context,
              icon: Icons.account_balance_wallet_rounded,
              title: 'Thêm vào Ví cá nhân',
              subtitle: 'Tiền mặt, Chuyển khoản, MoMo...',
              color: Colors.green.shade600,
              onTap: () {
                Navigator.pop(context);
                context.push('/add-transaction', extra: 'personal');
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border(context).withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold, 
                      fontSize: 16,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: AppColors.textLight(context), 
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textLight(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final int currentIndex = navigationShell.currentIndex;
    final double bottomPadding = MediaQuery.paddingOf(context).bottom;
    
    // Chiều cao của phần nền (không tính Safe Area). 
    final bool isAndroid = Theme.of(context).platform == TargetPlatform.android;
    // Giảm độ cao Android từ 70 xuống 60 để thanh menu trông gọn hơn
    final double appBarHeight = isAndroid ? 60 : (bottomPadding > 0 ? 42 : 60);

    return BottomAppBar(
      height: appBarHeight,
      shape: const CircularNotchedRectangle(),
      notchMargin: 6,
      color: Theme.of(context).cardColor,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      elevation: 20,
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildNavItem(
            context: context,
            icon: Icons.home_filled, 
            label: 'Trang chủ', 
            index: 0, 
            currentIndex: currentIndex,
            isAndroid: isAndroid,
          ),
          _buildNavItem(
            context: context,
            icon: Icons.account_balance_wallet_outlined, 
            label: 'Ví thẻ', 
            index: 1, 
            currentIndex: currentIndex,
            isAndroid: isAndroid,
          ),
          const SizedBox(width: 40), // Không gian cho Add FAB (Floating Action Button)
          _buildNavItem(
            context: context,
            icon: Icons.calendar_today_outlined, 
            label: 'Lịch hiển thị', 
            index: 2, 
            currentIndex: currentIndex,
            isAndroid: isAndroid,
          ),
          _buildNavItem(
            context: context,
            icon: Icons.person_outline_rounded, 
            label: 'Cá nhân', 
            index: 3, 
            currentIndex: currentIndex,
            isAndroid: isAndroid,
          ),
          ],
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon, 
    required String label, 
    required int index, 
    required int currentIndex,
    required bool isAndroid,
  }) {
    final isSelected = index == currentIndex;
    final double iconSize = isSelected ? 28.0 : 24.0;

    return IconButton(
      icon: Icon(
        icon,
        color: isSelected ? AppColors.primary(context) : AppColors.textLight(context),
        size: iconSize,
      ),
      onPressed: () {
        navigationShell.goBranch(
          index,
          initialLocation: index == currentIndex,
        );
      },
    );
  }
}
