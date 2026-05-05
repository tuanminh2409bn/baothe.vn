import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../constants/app_styles.dart';
import '../../../services/firestore_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/user_card_model.dart';
import '../../../models/user_wallet_model.dart';

class MobileWalletScreen extends ConsumerWidget {
  final int initialIndex;

  const MobileWalletScreen({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;
    final userCardsAsync = user != null 
        ? ref.watch(userCardsStreamProvider(user.uid))
        : AsyncValue<List<UserCard>>.data([]);
    
    final userWalletsAsync = user != null
        ? ref.watch(userWalletsStreamProvider(user.uid))
        : AsyncValue<List<UserWallet>>.data([]);

    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return DefaultTabController(
      length: 2,
      initialIndex: initialIndex,
      child: Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: _buildAppBar(context),
        body: TabBarView(
          children: [
            // Tab 1: Thẻ tín dụng
            userCardsAsync.when(
              data: (cards) => _buildCardsTab(context, cards, currencyFormat),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Lỗi: $e')),
            ),
            // Tab 2: Ví & Tài khoản
            userWalletsAsync.when(
              data: (wallets) => _buildWalletsTab(context, wallets, currencyFormat),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Lỗi: $e')),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: Text(
        'VÍ CỦA TÔI',
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          color: AppColors.textPrimary(context),
        ),
      ),
      bottom: TabBar(
        labelColor: AppColors.primary(context),
        unselectedLabelColor: AppColors.textLight(context),
        indicatorColor: AppColors.primary(context),
        indicatorWeight: 3,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: const [
          Tab(text: 'THẺ TÍN DỤNG'),
          Tab(text: 'TÀI KHOẢN & VÍ'),
        ],
      ),
    );
  }

  // --- CARDS TAB ---

  Widget _buildCardsTab(BuildContext context, List<UserCard> cards, NumberFormat format) {
    final totalLimit = cards.fold<double>(0, (sum, item) => sum + item.limit);
    final totalBalance = cards.fold<double>(0, (sum, item) => sum + item.balance);
    final totalAvailable = totalLimit - totalBalance;

    return RefreshIndicator(
      onRefresh: () async => {}, // Firestore stream tự cập nhật
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _buildTotalBalanceCard(context, totalBalance, totalAvailable, format, isCredit: true),
            const SizedBox(height: 30),
            _buildSectionHeader(context, 'Danh sách thẻ', '${cards.length} thẻ'),
            const SizedBox(height: 16),
            if (cards.isEmpty)
              _buildEmptyState(
                context,
                icon: FontAwesomeIcons.creditCard,
                title: 'Chưa có thẻ tín dụng',
                subtitle: 'Thêm thẻ ngay để quản lý hạn mức và hoàn tiền',
                onPressed: () => context.push('/add-card'),
              )
            else ...[
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cards.length,
                itemBuilder: (context, index) => _buildCardListItem(context, cards[index], format, index),
              ),
              const SizedBox(height: 20),
              _buildAddButton(context, 'THÊM THẺ TÍN DỤNG MỚI', () => context.push('/add-card')),
            ],
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // --- WALLETS TAB ---

  Widget _buildWalletsTab(BuildContext context, List<UserWallet> wallets, NumberFormat format) {
    final totalBalance = wallets.fold<double>(0, (sum, item) => sum + item.balance);

    return RefreshIndicator(
      onRefresh: () async => {},
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _buildTotalBalanceCard(context, totalBalance, 0, format, isCredit: false),
            const SizedBox(height: 30),
            _buildSectionHeader(context, 'Tài khoản & Ví', '${wallets.length} nguồn tiền'),
            const SizedBox(height: 16),
            if (wallets.isEmpty)
              _buildEmptyState(
                context,
                icon: FontAwesomeIcons.wallet,
                title: 'Chưa có ví cá nhân',
                subtitle: 'Thêm Tiền mặt, Ví MoMo hoặc ATM để quản lý',
                onPressed: () => context.push('/add-wallet'),
              )
            else ...[
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: wallets.length,
                itemBuilder: (context, index) => _buildWalletListItem(context, wallets[index], format, index),
              ),
              const SizedBox(height: 20),
              _buildAddButton(context, 'THÊM VÍ / TÀI KHOẢN MỚI', () => context.push('/add-wallet')),
            ],
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // --- COMMON WIDGETS ---

  Widget _buildSectionHeader(BuildContext context, String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context)),
        ),
        Text(
          subtitle,
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textLight(context)),
        ),
      ],
    );
  }

  Widget _buildAddButton(BuildContext context, String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add_rounded),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: AppColors.primary(context).withValues(alpha: 0.3)),
          foregroundColor: AppColors.primary(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
        ),
      ),
    );
  }

  Widget _buildTotalBalanceCard(BuildContext context, double balance, double available, NumberFormat format, {required bool isCredit}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            isCredit ? 'Tổng dư nợ hiện tại' : 'Tổng số dư hiện tại',
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary(context)),
          ),
          const SizedBox(height: 8),
          Text(
            format.format(balance),
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: isCredit ? AppColors.textPrimary(context) : Colors.green.shade700,
              letterSpacing: -1,
            ),
          ).animate().fadeIn().scale(),
          if (isCredit) ...[
            const SizedBox(height: 24),
            Divider(height: 1, color: AppColors.border(context)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBalanceDetail(context, 'Khả dụng', format.format(available), Colors.green),
                Container(width: 1, height: 40, color: AppColors.border(context)),
                _buildBalanceDetail(context, 'Ngày chốt', 'Hàng tháng', AppColors.primary(context)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBalanceDetail(BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight(context)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildCardListItem(BuildContext context, UserCard card, NumberFormat format, int index) {
    final usagePercent = card.limit > 0 ? (card.balance / card.limit).clamp(0.0, 1.0) : 0.0;
    
    return GestureDetector(
      onTap: () => context.push('/card-detail', extra: card),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: AppColors.background(context),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    card.imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(Icons.credit_card, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.cardName,
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      card.bankName,
                      style: GoogleFonts.inter(color: AppColors.textLight(context), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textLight(context)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Đã dùng ${format.format(card.balance)}',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Hạn mức ${format.format(card.limit)}',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight(context)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: usagePercent.toDouble(),
              minHeight: 6,
              backgroundColor: AppColors.border(context),
              valueColor: AlwaysStoppedAnimation<Color>(
                usagePercent > 0.8 ? Colors.red.shade400 : AppColors.primary(context),
              ),
            ),
          ),
        ],
      ),
    )).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.05);
  }

  Widget _buildWalletListItem(BuildContext context, UserWallet wallet, NumberFormat format, int index) {
    IconData icon;
    Color iconColor;

    switch (wallet.type) {
      case WalletType.cash:
        icon = Icons.money_rounded;
        iconColor = Colors.green;
        break;
      case WalletType.bankAccount:
        icon = Icons.account_balance_rounded;
        iconColor = Colors.blue;
        break;
      case WalletType.eWallet:
        icon = Icons.account_balance_wallet_rounded;
        iconColor = Colors.purple;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wallet.name,
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  wallet.type == WalletType.cash ? 'Tiền mặt' : (wallet.type == WalletType.bankAccount ? 'Tài khoản' : 'Ví điện tử'),
                  style: GoogleFonts.inter(color: AppColors.textLight(context), fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            format.format(wallet.balance),
            style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.textPrimary(context)),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.05);
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          FaIcon(icon, size: 48, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.textSecondary(context)),
          ),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight(context)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary(context),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('THÊM NGAY'),
          ),
        ],
      ),
    );
  }
}
