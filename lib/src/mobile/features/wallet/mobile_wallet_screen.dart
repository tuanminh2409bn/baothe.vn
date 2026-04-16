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

class MobileWalletScreen extends ConsumerWidget {
  const MobileWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;
    final userCardsAsync = user != null 
        ? ref.watch(userCardsStreamProvider(user.uid))
        : const AsyncValue<List<UserCard>>.data([]);

    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: _buildAppBar(context),
      body: userCardsAsync.when(
        data: (cards) => _buildBody(context, cards, currencyFormat),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Lỗi: $e')),
      ),
      floatingActionButton: _buildAddCardFab(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      title: Text(
        'VÍ CỦA TÔI',
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          color: AppColors.textPrimary,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_horiz_rounded),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, List<UserCard> cards, NumberFormat format) {
    final totalLimit = cards.fold<double>(0, (sum, item) => sum + item.limit);
    final totalBalance = cards.fold<double>(0, (sum, item) => sum + item.balance);
    final totalAvailable = totalLimit - totalBalance;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          _buildTotalBalanceCard(totalBalance, totalAvailable, format),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Danh sách thẻ',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${cards.length} thẻ',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (cards.isEmpty)
            _buildEmptyState()
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cards.length,
              itemBuilder: (context, index) {
                return _buildCardListItem(context, cards[index], format, index);
              },
            ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildTotalBalanceCard(double balance, double available, NumberFormat format) {
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
            'Tổng dư nợ hiện tại',
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            format.format(balance),
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -1,
            ),
          ).animate().fadeIn().scale(),
          const SizedBox(height: 24),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBalanceDetail('Khả dụng', format.format(available), Colors.green),
              Container(width: 1, height: 40, color: const Color(0xFFF3F4F6)),
              _buildBalanceDetail('Ngày chốt', 'Hàng tháng', AppColors.primary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceDetail(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight),
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
          border: Border.all(color: const Color(0xFFF3F4F6)),
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
                  color: const Color(0xFFF9FAFB),
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
                      style: GoogleFonts.inter(color: AppColors.textLight, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
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
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: usagePercent.toDouble(),
              minHeight: 6,
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: AlwaysStoppedAnimation<Color>(
                usagePercent > 0.8 ? Colors.red.shade400 : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    )).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.05);
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFF3F4F6), style: BorderStyle.none),
      ),
      child: Column(
        children: [
          FaIcon(FontAwesomeIcons.wallet, size: 48, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text(
            'Chưa có thẻ nào',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          Text(
            'Thêm thẻ ngay để bắt đầu quản lý',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }

  Widget _buildAddCardFab(BuildContext context) {
    return Padding(
      // Đẩy nút lên cao hơn thanh menu bên dưới
      padding: const EdgeInsets.only(bottom: 70),
      child: FloatingActionButton.extended(
        onPressed: () => context.push('/add-card'),
        backgroundColor: AppColors.primary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        label: Text(
          'THÊM THẺ MỚI',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: Colors.white,
          ),
        ),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    ).animate().slideY(begin: 0.1).fadeIn();
  }
}
