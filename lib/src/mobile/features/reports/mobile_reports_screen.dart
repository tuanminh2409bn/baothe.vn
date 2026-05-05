import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../constants/app_styles.dart';
import '../../../services/firestore_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/transaction_model.dart';
import '../../../models/user_card_model.dart';
import '../../../models/user_wallet_model.dart';

class MobileReportsScreen extends ConsumerWidget {
  const MobileReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;
    final transactionsAsync = user != null 
        ? ref.watch(transactionsStreamProvider(user.uid))
        : AsyncValue<List<Transaction>>.data([]);
    
    final userCardsAsync = user != null 
        ? ref.watch(userCardsStreamProvider(user.uid))
        : AsyncValue<List<UserCard>>.data([]);

    final userWalletsAsync = user != null
        ? ref.watch(userWalletsStreamProvider(user.uid))
        : AsyncValue<List<UserWallet>>.data([]);

    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'PHÂN TÍCH TÀI CHÍNH',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.2),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: TabBar(
            labelColor: AppColors.primary(context),
            unselectedLabelColor: AppColors.textLight(context),
            indicatorColor: AppColors.primary(context),
            indicatorWeight: 3,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(text: 'THẺ TÍN DỤNG'),
              Tab(text: 'CHI TIÊU CÁ NHÂN'),
            ],
          ),
        ),
        body: transactionsAsync.when(
          data: (txs) {
            final cards = userCardsAsync.value ?? [];
            final wallets = userWalletsAsync.value ?? [];
            return TabBarView(
              children: [
                _buildCreditReport(context, txs, cards, currencyFormat),
                _buildPersonalReport(context, txs, wallets, currencyFormat),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Lỗi: $e')),
        ),
      ),
    );
  }

  // --- CREDIT REPORT TAB ---
  Widget _buildCreditReport(BuildContext context, List<Transaction> allTxs, List<UserCard> cards, NumberFormat format) {
    final creditTxs = allTxs.where((tx) => tx.type == TransactionType.credit).toList();
    final bool isMock = creditTxs.isEmpty && cards.isEmpty;

    // Data for UI
    final totalSpending = isMock ? 12450000.0 : creditTxs.fold<double>(0, (sum, item) => sum + item.amount);
    final totalCashback = isMock ? 452000.0 : _calculateTotalCashback(creditTxs, cards);
    final cardData = _processCardData(creditTxs, cards, isMock);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMock) _buildDemoBadge(),
          _buildSummaryCards(context, totalSpending, totalCashback, format, isCredit: true),
          const SizedBox(height: 32),
          _buildSectionHeader(context, 'PHÂN BỔ THEO THẺ'),
          const SizedBox(height: 16),
          _buildCreditChartSection(context, cardData),
          const SizedBox(height: 32),
          _buildSectionHeader(context, 'CHI TIẾT TỪNG THẺ'),
          const SizedBox(height: 16),
          _buildCreditCardDetailList(context, cardData, totalSpending, format),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // --- PERSONAL REPORT TAB ---
  Widget _buildPersonalReport(BuildContext context, List<Transaction> allTxs, List<UserWallet> wallets, NumberFormat format) {
    final personalTxs = allTxs.where((tx) => tx.type == TransactionType.personal).toList();
    final bool isMock = personalTxs.isEmpty && wallets.isEmpty;

    final totalSpending = isMock ? 3450000.0 : personalTxs.fold<double>(0, (sum, item) => sum + item.amount);
    final categoryData = isMock 
        ? {'Ăn uống': 1200000.0, 'Mua sắm': 850000.0, 'Di chuyển': 400000.0, 'Khác': 1000000.0}
        : _processCategoryData(personalTxs);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMock) _buildDemoBadge(),
          _buildSummaryCards(context, totalSpending, 0, format, isCredit: false),
          const SizedBox(height: 32),
          _buildSectionHeader(context, 'PHÂN TÍCH DANH MỤC'),
          const SizedBox(height: 16),
          _buildCategoryChartSection(context, categoryData),
          const SizedBox(height: 32),
          _buildSectionHeader(context, 'CHI TIÊU THEO HẠNG MỤC'),
          const SizedBox(height: 16),
          _buildCategoryList(context, categoryData, totalSpending, format),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // --- HELPER METHODS & UI WIDGETS ---

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.textSecondary(context), letterSpacing: 1),
    );
  }

  Widget _buildSummaryCards(BuildContext context, double spending, double cashback, NumberFormat format, {required bool isCredit}) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isCredit ? AppColors.primary(context) : Colors.green.shade700,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (isCredit ? AppColors.primary(context) : Colors.green).withValues(alpha: 0.2), 
                  blurRadius: 15, 
                  offset: const Offset(0, 8)
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tổng chi tiêu', style: GoogleFonts.inter(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  format.format(spending),
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ),
        if (isCredit) ...[
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tiền đã hoàn', style: GoogleFonts.inter(color: AppColors.textSecondary(context), fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    format.format(cashback),
                    style: GoogleFonts.inter(color: Colors.green.shade700, fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1);
  }

  Widget _buildCreditChartSection(BuildContext context, Map<String, double> data) {
    return Container(
      height: 260,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 20)],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 4,
              centerSpaceRadius: 60,
              sections: _getChartSections(data),
            ),
          ).animate().fadeIn(duration: 800.ms),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Dùng Thẻ', style: GoogleFonts.inter(color: AppColors.textLight(context), fontSize: 12)),
              Text('CREDIT', style: GoogleFonts.inter(color: AppColors.textPrimary(context), fontWeight: FontWeight.w900, fontSize: 18)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChartSection(BuildContext context, Map<String, double> data) {
    return Container(
      height: 260,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 20)],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 4,
              centerSpaceRadius: 60,
              sections: _getChartSections(data),
            ),
          ).animate().fadeIn(duration: 800.ms),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Hạng mục', style: GoogleFonts.inter(color: AppColors.textLight(context), fontSize: 12)),
              Text('CÁ NHÂN', style: GoogleFonts.inter(color: AppColors.textPrimary(context), fontWeight: FontWeight.w900, fontSize: 18)),
            ],
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _getChartSections(Map<String, double> data) {
    final colors = [
      const Color(0xFF6366F1), const Color(0xFFF59E0B), const Color(0xFFEC4899), 
      const Color(0xFF10B981), const Color(0xFF8B5CF6), const Color(0xFFF43F5E),
    ];
    int i = 0;
    return data.entries.map((e) {
      final color = colors[i % colors.length];
      i++;
      return PieChartSectionData(
        color: color,
        value: e.value,
        title: '',
        radius: 25,
        badgeWidget: _buildBadge(e.key, color),
        badgePositionPercentageOffset: 1.4,
      );
    }).toList();
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8)],
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(color: color, fontSize: 9, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _buildCreditCardDetailList(BuildContext context, Map<String, double> data, double total, NumberFormat format) {
    return Column(
      children: data.entries.map((e) {
        final percent = (total > 0 ? (e.value / total * 100) : 0).toStringAsFixed(1);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.background(context),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.credit_card, color: AppColors.primary(context), size: 18),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.key, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('$percent% tổng quẹt thẻ', style: GoogleFonts.inter(color: AppColors.textLight(context), fontSize: 12)),
                  ],
                ),
              ),
              Text(format.format(e.value), style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textPrimary(context))),
            ],
          ),
        ).animate().fadeIn().slideX(begin: 0.1);
      }).toList(),
    );
  }

  Widget _buildCategoryList(BuildContext context, Map<String, double> data, double total, NumberFormat format) {
    return Column(
      children: data.entries.map((e) {
        final percent = (total > 0 ? (e.value / total * 100) : 0).toStringAsFixed(1);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.background(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_getCategoryIcon(e.key), color: Colors.green.shade700, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.key, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('$percent% tổng chi cá nhân', style: GoogleFonts.inter(color: AppColors.textLight(context), fontSize: 12)),
                  ],
                ),
              ),
              Text(format.format(e.value), style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textPrimary(context))),
            ],
          ),
        ).animate().fadeIn().slideX(begin: 0.1);
      }).toList(),
    );
  }

  Widget _buildDemoBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'DỮ LIỆU MẪU: Hãy thêm giao dịch thật để xem phân tích chính xác.',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.orange.shade800, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Siêu thị': return Icons.local_grocery_store_outlined;
      case 'Ẩm thực': return Icons.restaurant_rounded;
      case 'Mua sắm': return Icons.shopping_bag_outlined;
      case 'Di chuyển': return Icons.directions_car_filled_outlined;
      case 'Giải trí': return Icons.confirmation_number_outlined;
      case 'Hoá đơn': return Icons.receipt_long_outlined;
      default: return Icons.grid_view_rounded;
    }
  }

  Map<String, double> _processCategoryData(List<Transaction> transactions) {
    Map<String, double> data = {};
    for (var tx in transactions) {
      data[tx.category] = (data[tx.category] ?? 0) + tx.amount;
    }
    return data;
  }

  Map<String, double> _processCardData(List<Transaction> transactions, List<UserCard> cards, bool isMock) {
    if (isMock) return {'Thẻ Cashback': 4500000.0, 'Thẻ Du lịch': 5000000.0, 'Thẻ Siêu thị': 2950000.0};
    
    Map<String, double> data = {};
    for (var tx in transactions) {
      data[tx.sourceName] = (data[tx.sourceName] ?? 0) + tx.amount;
    }
    return data;
  }

  double _calculateTotalCashback(List<Transaction> txs, List<UserCard> cards) {
    double total = 0;
    for (var tx in txs) {
      final card = cards.any((c) => c.id == tx.userCardId) ? cards.firstWhere((c) => c.id == tx.userCardId) : null;
      if (card != null) {
        final rate = _getCashbackRateForCategory(card, tx.category);
        total += (tx.amount * rate) / 100;
      }
    }
    return total;
  }

  double _getCashbackRateForCategory(UserCard card, String category) {
    switch (category) {
      case 'Siêu thị': return card.supermarketCashbackRate ?? 0;
      case 'Ẩm thực': return card.diningCashbackRate ?? 0;
      case 'Mua sắm': return card.shoppingCashbackRate ?? 0;
      case 'Online': return card.onlineCashbackRate ?? 0;
      case 'Di chuyển': return card.transportCashbackRate ?? 0;
      case 'Giải trí': return card.entertainmentCashbackRate ?? 0;
      case 'Y tế': return card.medicalCashbackRate ?? 0;
      case 'Giáo dục': return card.educationCashbackRate ?? 0;
      case 'Gym': return card.gymCashbackRate ?? 0;
      case 'Bảo hiểm': return card.insuranceCashbackRate ?? 0;
      case 'Hoá đơn': return card.utilitiesCashbackRate ?? 0;
      default: return card.otherCashbackRate ?? 0;
    }
  }
}
