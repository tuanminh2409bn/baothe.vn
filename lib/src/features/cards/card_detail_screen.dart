import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../constants/app_styles.dart';
import '../../models/credit_card_model.dart';
import '../../common_widgets/animated_hover.dart'; // Giả định đã có widget này

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/firestore_service.dart';
import '../comparison/comparison_provider.dart';

class CardDetailScreen extends ConsumerWidget {
  final String cardId;

  const CardDetailScreen({super.key, required this.cardId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Lấy dữ liệu từ Firestore dựa trên ID
    final cardAsync = ref.watch(cardDetailProvider(cardId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: cardAsync.when(
          data: (card) => Text(card?.bankName ?? 'Chi tiết thẻ', style: AppStyles.h2),
          loading: () => Text('Đang tải...', style: AppStyles.h2),
          error: (_, __) => Text('Lỗi', style: AppStyles.h2),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go('/'),
        ),
      ),
      body: cardAsync.when(
        data: (card) {
          if (card == null) {
            return const Center(child: Text('Không tìm thấy thông tin thẻ.'));
          }
          final isWeb = MediaQuery.of(context).size.width > 900;
          return SingleChildScrollView(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1200),
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                child: isWeb ? _buildWebLayout(context, card, ref) : _buildMobileLayout(context, card, ref),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accentOrange)),
        error: (err, stack) => Center(child: Text('Đã có lỗi xảy ra: $err')),
      ),
    );
  }

  Widget _buildWebLayout(BuildContext context, CreditCard card, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cột trái: Hình ảnh thẻ
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Hero(
                tag: card.id,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentOrange.withValues(alpha: 0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: card.imagePath.startsWith('http')
                        ? Image.network(
                            card.imagePath,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 250,
                              color: AppColors.border,
                              child: const Icon(Icons.credit_card, size: 80, color: AppColors.textLight),
                            ),
                          )
                        : Image.asset(
                            card.imagePath,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 250,
                              color: AppColors.border,
                              child: const Icon(Icons.credit_card, size: 80, color: AppColors.textLight),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _buildActionButtons(context, card, ref),
            ],
          ),
        ),
        const SizedBox(width: 60),
        // Cột phải: Thông tin chi tiết
        Expanded(
          flex: 3,
          child: _buildInfoContent(card),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context, CreditCard card, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Hero(
            tag: card.id,
            child: card.imagePath.startsWith('http')
                ? Image.network(
                    card.imagePath,
                    width: 300,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      color: AppColors.border,
                      child: const Icon(Icons.credit_card, size: 60, color: AppColors.textLight),
                    ),
                  )
                : Image.asset(
                    card.imagePath,
                    width: 300,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      color: AppColors.border,
                      child: const Icon(Icons.credit_card, size: 60, color: AppColors.textLight),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 32),
        _buildInfoContent(card),
        const SizedBox(height: 40),
        _buildActionButtons(context, card, ref),
      ],
    );
  }

  Widget _buildInfoContent(CreditCard card) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          card.name,
          style: AppStyles.h1.copyWith(fontSize: 32),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.accentOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.accentOrange.withValues(alpha: 0.3)),
          ),
          child: Text(
            card.cashbackHighlight,
            style: AppStyles.labelSmall.copyWith(
              color: AppColors.accentOrange,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 40),
        _buildSectionTitle('Đặc quyền nổi bật'),
        const SizedBox(height: 16),
        ...card.details.map((detail) => _buildBenefitItem(detail)),
        if (card.benefits != null)
          ...card.benefits!.map((benefit) => _buildBenefitItem(benefit)),
        
        const SizedBox(height: 32),
        _buildSectionTitle('Thông tin biểu phí'),
        const SizedBox(height: 16),
        _buildFeeRow('Phí thường niên', card.annualFee != null ? '${card.annualFee!.toInt()} VND' : 'Đang cập nhật'),
        _buildFeeRow('Lãi suất', card.interestRate != null ? '${card.interestRate}%/năm' : 'Đang cập nhật'),
        _buildFeeRow('Loại thẻ', card.cardType ?? 'N/A'),
        _buildFeeRow('Hạng thẻ', card.cardTier ?? 'N/A'),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppStyles.h2.copyWith(fontSize: 20, color: AppColors.primary),
    );
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          Text(value, style: AppStyles.h2.copyWith(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, CreditCard card, WidgetRef ref) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              // Mở link đăng ký
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text('Mở thẻ ngay', style: AppStyles.buttonText),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: () {
              ref.read(comparisonProvider.notifier).addCard(card);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã thêm ${card.name} vào danh sách so sánh'),
                  action: SnackBarAction(
                    label: 'SO SÁNH',
                    onPressed: () => context.go('/compare'),
                  ),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Thêm vào so sánh', style: AppStyles.buttonText.copyWith(color: AppColors.primary)),
          ),
        ),
      ],
    );
  }
}
