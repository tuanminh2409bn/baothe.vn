import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'cards/home_screen.dart';
import 'management/wallet_screen.dart';
import 'spending/spending_screen.dart';
import 'spending/spending_analysis_screen.dart';
import '../constants/app_styles.dart';
import '../services/auth_service.dart';
import '../common_widgets/auth_placeholder.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _selectedIndex = 3; // Mặc định là trang Khám phá

  // Hàm trả về Widget tương ứng với Index (Lazy Loading)
  Widget _buildBody(int index) {
    switch (index) {
      case 0: return const WalletScreen();
      case 1: return const SpendingScreen();
      case 2: return const SpendingAnalysisScreen();
      case 3: return const HomeScreen();
      case 4: return const ProfileScreen();
      default: return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 900;

    debugPrint('--- [UI] MainScreen build triggered (isWeb: $isWeb, index: $_selectedIndex) ---');

    if (isWeb) {
      return _buildWebLayout();
    }

    return _buildMobileLayout();
  }

  // GIAO DIỆN MOBILE
  Widget _buildMobileLayout() {
    return Scaffold(
      // KHÔNG dùng IndexedStack để tránh khởi tạo lỗi các trang con
      body: _buildBody(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary(context),
        unselectedItemColor: AppColors.textLight(context),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), activeIcon: Icon(Icons.account_balance_wallet), label: 'Ví thẻ'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'Chi tiêu'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart), label: 'Phân tích'),
          BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), activeIcon: Icon(Icons.explore), label: 'Khám phá'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Tôi'),
        ],
      ),
    );
  }

  // GIAO DIỆN WEB
  Widget _buildWebLayout() {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(5, 0),
                )
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 40),
                Image.asset('assets/logo/logo_web.png', height: 50),
                const SizedBox(height: 40),
                
                _buildSidebarItem(0, Icons.account_balance_wallet, 'Ví thẻ của tôi'),
                _buildSidebarItem(1, Icons.receipt_long, 'Quản lý chi tiêu'),
                _buildSidebarItem(2, Icons.bar_chart, 'Phân tích tài chính'),
                _buildSidebarItem(3, Icons.explore, 'Khám phá thẻ mới'),
                const Spacer(),
                _buildSidebarItem(4, Icons.person, 'Trang cá nhân'),
                const SizedBox(height: 20),
              ],
            ),
          ),
          
          // Main Content - Chỉ render trang được chọn
          Expanded(
            child: _buildBody(_selectedIndex),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary(context).withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon, 
                color: isSelected ? AppColors.primary(context) : AppColors.textLight(context),
                size: 24,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.primary(context) : AppColors.textPrimary(context),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;

    if (user == null) {
      return const Scaffold(
        body: AuthPlaceholder(message: 'Vui lòng đăng nhập để xem thông tin cá nhân'),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('Cá Nhân'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person, size: 100, color: AppColors.primary(context)),
            const SizedBox(height: 20),
            Text(user.email ?? 'Người dùng', style: AppStyles.h3(context)),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => ref.read(authServiceProvider).signOut(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Đăng xuất'),
            ),
          ],
        ),
      ),
    );
  }
}
