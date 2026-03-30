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
          final cards = userCardsAsync.valueOrNull ?? [];
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
    
    // Dữ liệu mẫu đẳng cấp
    final totalSpending = isMock ? 12450000.0 : txs.fold<double>(0, (sum, item) => sum + item.amount);
    final categoryData = isMock 
        ? {
            'Mua sắm': 4500000.0,
            'Ăn uống': 2800000.0,
            'Di chuyển': 1200000.0,
            'Giải trí': 2100000.0,
            'Khác': 1850000.0,
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
        children: [
          const SizedBox(height: 20),
          if (isMock) _buildDemoBadge(),
          const SizedBox(height: 10),
          _buildSummaryCard(totalSpending, currencyFormat),
          const SizedBox(height: 32),
          _buildChartSection(categoryData),
          const SizedBox(height: 32),
          _buildCategoryList(categoryData, totalSpending, currencyFormat),
          const SizedBox(height: 40),
        ],
      ),
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
              'DỮ LIỆU MẪU: Hãy thêm giao dịch thật để xem phân tích chi tiêu chính xác của bạn.',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.orange.shade800, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.2);
  }

  Widget _buildSummaryCard(double total, NumberFormat format) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          Text('Tổng chi tiêu tháng này', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            format.format(total),
            style: GoogleFonts.inter(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1),
          ).animate().fadeIn(delay: 200.ms).scale(),
        ],
      ),
    );
  }

  Widget _buildChartSection(Map<String, double> data) {
    return Container(
      height: 320,
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
              centerSpaceRadius: 70,
              sections: _getChartSections(data),
            ),
          ).animate().fadeIn(duration: 800.ms).rotate(begin: 0.1, end: 0),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Hạng mục', style: GoogleFonts.inter(color: AppColors.textLight, fontSize: 12)),
              Text('TOP 1', style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
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
        radius: 35,
        badgeWidget: _buildBadge(e.key, color),
        badgePositionPercentageOffset: 1.5,
      );
    }).toList();
  }

  Widget _buildBadge(String category, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8)],
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        category,
        style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _buildCategoryList(Map<String, double> data, double total, NumberFormat format) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Phân tích chi tiết', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
            const Icon(Icons.sort_rounded, size: 20, color: AppColors.textLight),
          ],
        ),
        const SizedBox(height: 16),
        ...data.entries.map((e) {
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
        }),
      ],
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Mua sắm': return Icons.shopping_bag_outlined;
      case 'Ăn uống': return Icons.restaurant_rounded;
      case 'Di chuyển': return Icons.directions_car_filled_outlined;
      case 'Giải trí': return Icons.confirmation_number_outlined;
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
