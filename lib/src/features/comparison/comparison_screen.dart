import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../constants/app_styles.dart';
import '../../models/credit_card_model.dart';
import 'comparison_provider.dart';

class ComparisonScreen extends ConsumerWidget {
  const ComparisonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comparisonCards = ref.watch(comparisonProvider);
    final isWeb = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('So sánh thẻ tín dụng', style: AppStyles.h2),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go('/'),
        ),
        actions: [
          if (comparisonCards.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(comparisonProvider.notifier).clearAll(),
              child: const Text('Xóa tất cả', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
      body: comparisonCards.isEmpty
          ? _buildEmptyState(context)
          : SingleChildScrollView(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  child: _buildComparisonTable(context, comparisonCards, isWeb),
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.compare_arrows, size: 80, color: AppColors.textLight),
          const SizedBox(height: 20),
          Text('Danh sách so sánh đang trống', style: AppStyles.h2),
          const SizedBox(height: 12),
          Text('Hãy chọn các thẻ bạn quan tâm để bắt đầu so sánh', style: AppStyles.bodyMedium),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => context.go('/'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Quay lại trang chủ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonTable(BuildContext context, List<CreditCard> cards, bool isWeb) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        children: [
          // Hàng Header: Hình ảnh và Tên thẻ
          Row(
            children: [
              const SizedBox(width: 200), // Khoảng trống cho cột nhãn bên trái
              ...cards.map((card) => _buildCardHeader(context, card)),
            ],
          ),
          const SizedBox(height: 24),
          // Các hàng thông số
          _buildComparisonRow('Ngân hàng', cards.map((c) => c.bankName).toList()),
          _buildComparisonRow('Phí thường niên', cards.map((c) => c.annualFee != null ? '${c.annualFee!.toInt()} VND' : 'N/A').toList()),
          _buildComparisonRow('Lãi suất', cards.map((c) => c.interestRate != null ? '${c.interestRate}%/năm' : 'N/A').toList()),
          _buildComparisonRow('Loại thẻ', cards.map((c) => c.cardType ?? 'N/A').toList()),
          _buildComparisonRow('Hạng thẻ', cards.map((c) => c.cardTier ?? 'N/A').toList()),
          _buildComparisonRow('Ưu đãi chính', cards.map((c) => c.cashbackHighlight).toList(), isExpandable: true),
        ],
      ),
    );
  }

  Widget _buildCardHeader(BuildContext context, CreditCard card) {
    return Container(
      width: 250,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Image.asset(
            card.imagePath,
            height: 120,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 120,
              width: 180,
              color: AppColors.border,
              child: const Icon(Icons.credit_card, size: 50, color: AppColors.textLight),
            ),
          ),
          const SizedBox(height: 12),
          Text(card.name, textAlign: TextAlign.center, style: AppStyles.h2.copyWith(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(String label, List<String> values, {bool isExpandable = false}) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          // Cột nhãn
          Container(
            width: 200,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            color: AppColors.surface,
            child: Text(label, style: AppStyles.h2.copyWith(fontSize: 14, color: AppColors.textSecondary)),
          ),
          // Các cột giá trị
          ...values.map((val) => Container(
                width: 250,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Text(
                  val,
                  textAlign: TextAlign.center,
                  style: AppStyles.bodyMedium.copyWith(fontSize: 14),
                ),
              )),
        ],
      ),
    );
  }
}
