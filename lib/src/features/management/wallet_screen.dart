import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../constants/app_styles.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_card_model.dart';
import 'package:intl/intl.dart';

import '../../common_widgets/auth_placeholder.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authServiceProvider);
    final user = auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: AuthPlaceholder(),
      );
    }

    final userCardsAsync = ref.watch(userCardsStreamProvider(user.uid));
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ví Thẻ Của Tôi'),
        actions: [
          IconButton(
            onPressed: () => context.push('/add-card'),
            icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: userCardsAsync.when(
        data: (cards) {
          if (cards.isEmpty) {
            return _buildEmptyState(context);
          }

          final totalLimit = cards.fold<double>(0, (sum, item) => sum + item.limit);
          final totalBalance = cards.fold<double>(0, (sum, item) => sum + item.balance);

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(userCardsStreamProvider(user.uid)),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSummaryCard(totalLimit, totalBalance, currencyFormat),
                const SizedBox(height: 24),
                Text('Danh sách thẻ (${cards.length})', style: AppStyles.h3),
                const SizedBox(height: 16),
                ...cards.map((card) => _buildCardItem(context, card, currencyFormat)),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Lỗi: $e')),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.credit_card_off_outlined, size: 80, color: AppColors.textLight.withValues(alpha: 0.5)),
          const SizedBox(height: 20),
          Text('Ví của bạn đang trống', style: AppStyles.h3),
          const SizedBox(height: 10),
          Text('Hãy thêm thẻ tín dụng đầu tiên để quản lý', style: AppStyles.labelSmall),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => context.push('/add-card'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Thêm thẻ ngay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(double totalLimit, double totalBalance, NumberFormat format) {
    final available = totalLimit - totalBalance;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A1A), Color(0xFF333333)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppStyles.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tổng dư nợ', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
              const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            format.format(totalBalance),
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem('Hạn mức', format.format(totalLimit)),
              _buildSummaryItem('Khả dụng', format.format(available)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildCardItem(BuildContext context, UserCard card, NumberFormat format) {
    final usagePercent = card.limit > 0 ? (card.balance / card.limit).clamp(0.0, 1.0) : 0.0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Xem chi tiết thẻ hoặc lịch sử chi tiêu của thẻ này
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Hình ảnh thẻ (giả lập hoặc icon ngân hàng)
                Container(
                  width: 60,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      card.imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.credit_card, color: AppColors.textLight),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(card.cardName, style: AppStyles.h4, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(card.bankName, style: AppStyles.labelSmall),
                      const SizedBox(height: 8),
                      // Progress bar chi tiêu
                      LinearProgressIndicator(
                        value: usagePercent.toDouble(),
                        backgroundColor: Colors.grey[200],
                        color: usagePercent > 0.8 ? Colors.red : AppColors.primary,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Đã dùng: ${format.format(card.balance)}', style: const TextStyle(fontSize: 11)),
                          Text('${(usagePercent * 100).toInt()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textLight),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
