import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../constants/app_styles.dart';
import '../../../services/firestore_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/user_wallet_model.dart';
import '../../../models/transaction_model.dart';

class MobileWalletDetailScreen extends ConsumerWidget {
  final UserWallet wallet;

  const MobileWalletDetailScreen({super.key, required this.wallet});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;
    final transactionsAsync = user != null
        ? ref.watch(filteredTransactionsProvider((userId: user.uid, walletId: wallet.id, cardId: null)))
        : const AsyncValue<List<Transaction>>.data([]);

    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWalletInfoCard(context, currencyFormat),
                  const SizedBox(height: 32),
                  _buildSectionHeader(context, 'Lịch sử giao dịch'),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          transactionsAsync.when(
            data: (transactions) => transactions.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(context),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildTransactionItem(
                        context,
                        transactions[index],
                        currencyFormat,
                        dateFormat,
                        index,
                      ),
                      childCount: transactions.length,
                    ),
                  ),
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(child: Text('Lỗi: $e')),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => context.pop(),
        color: AppColors.textPrimary(context),
      ),
      title: Text(
        wallet.name.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          color: AppColors.textPrimary(context),
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildWalletInfoCard(BuildContext context, NumberFormat format) {
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            'Số dư hiện tại',
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary(context)),
          ),
          const SizedBox(height: 8),
          Text(
            format.format(wallet.balance),
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary(context),
              letterSpacing: -1,
            ),
          ).animate().fadeIn().scale(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary(context),
      ),
    );
  }

  Widget _buildTransactionItem(
    BuildContext context,
    Transaction tx,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
    int index,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getCategoryIcon(tx.category),
              color: AppColors.textSecondary(context),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.note.isNotEmpty ? tx.note : tx.category,
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  dateFormat.format(tx.timestamp),
                  style: GoogleFonts.inter(color: AppColors.textLight(context), fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '-${currencyFormat.format(tx.amount)}',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: Colors.red.shade700,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.05);
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text(
            'Chưa có giao dịch nào',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.textSecondary(context)),
          ),
          Text(
            'Bắt đầu thêm chi tiêu để quản lý ví tốt hơn',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight(context)),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Mua sắm': return Icons.shopping_bag_rounded;
      case 'Ăn uống': return Icons.fastfood_rounded;
      case 'Di chuyển': return Icons.directions_car_rounded;
      case 'Giải trí': return Icons.movie_rounded;
      case 'Hoá đơn': return Icons.receipt_long_rounded;
      case 'Siêu thị': return Icons.local_grocery_store_rounded;
      case 'Online': return Icons.language_rounded;
      case 'Du lịch': return Icons.flight_takeoff_rounded;
      case 'Y tế': return Icons.local_hospital_rounded;
      case 'Giáo dục': return Icons.school_rounded;
      case 'Bảo hiểm': return Icons.shield_rounded;
      case 'Gym': return Icons.fitness_center_rounded;
      case 'Spa/Làm đẹp': return Icons.spa_rounded;
      default: return Icons.more_horiz_rounded;
    }
  }
}
