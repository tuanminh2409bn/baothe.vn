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

class MobileReportsScreen extends ConsumerWidget {
  const MobileReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;
    final transactionsAsync = user != null 
        ? ref.watch(transactionsStreamProvider(user.uid))
        : const AsyncValue<List<Transaction>>.data([]);
    
    final userCardsAsync = user != null 
        ? ref.watch(userCardsStreamProvider(user.uid))
        : const AsyncValue<List<UserCard>>.data([]);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'BÁO CÁO CHI TIÊU',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.2),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: transactionsAsync.when(
        data: (txs) {
          final cards = userCardsAsync.value ?? [];
          return _buildBody(context, txs, cards);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Lỗi: $e')),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<Transaction> txs, List<UserCard> cards) {
    final bool isMock = txs.isEmpty && cards.isEmpty;
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    
    final totalSpending = isMock ? 12450000.0 : txs.fold<double>(0, (sum, item) => sum + item.amount);
    
    // Tính toán Cashback thực tế
    final totalCashback = isMock ? 452000.0 : _calculateTotalCashback(txs, cards);

    final categoryData = isMock 
        ? {
            'Mua sắm': 4500000.0,
            'Ẩm thực': 2800000.0,
            'Di chuyển': 1200000.0,
            'Giải trí': 2100000.0,
            'Siêu thị': 1850000.0,
          }
        : _processCategoryData(txs);

    if (txs.isEmpty && !isMock) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.analytics_outlined, size: 60, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'Chưa có dữ liệu chi tiêu',
                style: GoogleFonts.inter(fontSize: 18, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Thêm giao dịch mới tại trang Chủ để xem báo cáo',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: AppColors.textLight),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          if (isMock) _buildDemoBadge(),
          _buildSummarySection(totalSpending, totalCashback, currencyFormat),
          const SizedBox(height: 32),
          Text(
            'PHÂN TÍCH DANH MỤC',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.textSecondary, letterSpacing: 1),
          ),
          const SizedBox(height: 16),
          _buildChartSection(categoryData),
          const SizedBox(height: 32),
          Text(
            'CHI TIÊU THEO HẠNG MỤC',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.textSecondary, letterSpacing: 1),
          ),
          const SizedBox(height: 16),
          _buildCategoryList(categoryData, totalSpending, currencyFormat),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  double _calculateTotalCashback(List<Transaction> txs, List<UserCard> cards) {
    double total = 0;
    for (var tx in txs) {
      // Tìm thẻ được dùng trong giao dịch này
      final card = cards.any((c) => c.id == tx.userCardId) 
          ? cards.firstWhere((c) => c.id == tx.userCardId)
          : null;
      
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
              'DỮ LIỆU MẪU: Hãy thêm giao dịch thật để xem phân tích chi tiêu chính xác.',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.orange.shade800, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.2);
  }

  Widget _buildSummarySection(double spending, double cashback, NumberFormat format) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 8)),
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
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF3F4F6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tiền đã hoàn', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
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
    ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1);
  }

  Widget _buildChartSection(Map<String, double> data) {
    return Container(
      height: 300,
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
              centerSpaceRadius: 65,
              sections: _getChartSections(data),
            ),
          ).animate().fadeIn(duration: 800.ms).rotate(begin: 0.1, end: 0),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Hạng mục', style: GoogleFonts.inter(color: AppColors.textLight, fontSize: 12)),
              Text('CHI TIÊU', style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
            ],
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _getChartSections(Map<String, double> data) {
    final colors = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFFF59E0B), // Orange
      const Color(0xFFEC4899), // Pink
      const Color(0xFF10B981), // Teal
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFF43F5E), // Red
    ];
    int i = 0;
    return data.entries.map((e) {
      final color = colors[i % colors.length];
      i++;
      return PieChartSectionData(
        color: color,
        value: e.value,
        title: '',
        radius: 30,
        badgeWidget: _buildBadge(e.key, color),
        badgePositionPercentageOffset: 1.4,
      );
    }).toList();
  }

  Widget _buildBadge(String category, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8)],
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Text(
        category,
        style: GoogleFonts.inter(color: color, fontSize: 9, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _buildCategoryList(Map<String, double> data, double total, NumberFormat format) {
    return Column(
      children: data.entries.map((e) {
        final percent = (e.value / total * 100).toStringAsFixed(1);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF3F4F6)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_getCategoryIcon(e.key), color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.key, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('$percent% tổng chi tiêu', style: GoogleFonts.inter(color: AppColors.textLight, fontSize: 12)),
                  ],
                ),
              ),
              Text(format.format(e.value), style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
            ],
          ),
        ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1);
      }).toList(),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Siêu thị': return Icons.local_grocery_store_outlined;
      case 'Ẩm thực': return Icons.restaurant_rounded;
      case 'Mua sắm': return Icons.shopping_bag_outlined;
      case 'Di chuyển': return Icons.directions_car_filled_outlined;
      case 'Giải trí': return Icons.confirmation_number_outlined;
      case 'Online': return Icons.shopping_cart_outlined;
      case 'Y tế': return Icons.local_hospital_outlined;
      case 'Giáo dục': return Icons.school_outlined;
      case 'Gym': return Icons.fitness_center_outlined;
      case 'Bảo hiểm': return Icons.shield_outlined;
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
}
