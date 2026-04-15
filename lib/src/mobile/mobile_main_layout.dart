import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
        const Positioned(
          right: 0,
          bottom: 100, // Đặt cao hơn bottom nav bar
          child: FinyAIFloatingButton(),
        ),
      ],
    );
  }

  Widget _buildAddFab(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => context.push('/add-card'),
      backgroundColor: AppColors.primary,
      shape: const CircleBorder(),
      child: const Icon(Icons.add, color: Colors.white, size: 30),
    ); // Thêm animation sau nếu cần
  }


  Widget _buildBottomNav(BuildContext context) {
    final int currentIndex = navigationShell.currentIndex;
    final double bottomPadding = MediaQuery.paddingOf(context).bottom;
    
    // Chiều cao của phần nền (không tính Safe Area). 
    // Mặc định Android (không có tai thỏ) là 60px cho dễ bóm.
    // Với iOS (có bottomPadding ~ 34px), ta chỉ cần phần nền cao 42px. 
    // Tổng chiều cao iOS sẽ là: 42 + 34 = 76px (rất mỏng gọn).
    // Việc hạ chiều cao nền này sẽ TỰ ĐỘNG kéo dấu X (FAB) thấp xuống theo viền mép trên của BottomAppBar.
    final double appBarHeight = bottomPadding > 0 ? 42 : 60;

    return BottomAppBar(
      height: appBarHeight,
      shape: const CircularNotchedRectangle(),
      notchMargin: 6,
      color: Colors.white,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      elevation: 20,
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildNavItem(
            icon: Icons.home_filled, 
            label: 'Trang chủ', 
            index: 0, 
            currentIndex: currentIndex,
          ),
          _buildNavItem(
            icon: Icons.account_balance_wallet_outlined, 
            label: 'Ví thẻ', 
            index: 1, 
            currentIndex: currentIndex,
          ),
          const SizedBox(width: 40), // Không gian cho Add FAB (Floating Action Button)
          _buildNavItem(
            icon: Icons.calendar_today_outlined, 
            label: 'Lịch hiển thị', 
            index: 2, 
            currentIndex: currentIndex,
          ),
          _buildNavItem(
            icon: Icons.person_outline_rounded, 
            label: 'Cá nhân', 
            index: 3, 
            currentIndex: currentIndex,
          ),
          ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon, 
    required String label, 
    required int index, 
    required int currentIndex
  }) {
    final isSelected = index == currentIndex;
    return IconButton(
      icon: Icon(
        icon,
        color: isSelected ? AppColors.primary : AppColors.textLight,
        size: isSelected ? 28 : 24,
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
