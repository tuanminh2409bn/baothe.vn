import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../constants/app_styles.dart';
import '../../models/credit_card_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/firestore_service.dart';
import '../comparison/comparison_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../favorites/favorites_provider.dart';

class CardDetailScreen extends ConsumerStatefulWidget {
  final String cardId;
  const CardDetailScreen({super.key, required this.cardId});

  @override
  ConsumerState<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends ConsumerState<CardDetailScreen> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final cardAsync = ref.watch(cardDetailProvider(widget.cardId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: cardAsync.when(
          data: (card) => Text(card?.bankName ?? 'Chi tiết thẻ', style: AppStyles.h2),
          loading: () => Text('Đang tải...', style: AppStyles.h2),
          error: (_, __) => Text('Lỗi', style: AppStyles.h2),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.primary),
          onPressed: () => context.go('/'),
        ),
        actions: [
          cardAsync.when(
            data: (card) {
              if (card == null) return const SizedBox.shrink();
              final favorites = ref.watch(favoritesProvider);
              final isFavorite = favorites.contains(card.id);
              return IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : AppColors.primary,
                ),
                onPressed: () {
                  ref.read(favoritesProvider.notifier).toggleFavorite(card.id);
                },
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: cardAsync.when(
        data: (card) {
          if (card == null) return const Center(child: Text('Không tìm thấy thẻ.'));
          final isWeb = MediaQuery.of(context).size.width > 900;
          return SingleChildScrollView(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1200),
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                child: isWeb ? _buildWebLayout(card) : _buildMobileLayout(card),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, stack) => Center(child: Text('Lỗi: $err')),
      ),
    );
  }

  Widget _buildWebLayout(CreditCard card) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            children: [
              _buildCardImage(card),
              const SizedBox(height: 32),
              _buildActionButtons(card),
            ],
          ),
        ),
        const SizedBox(width: 60),
        Expanded(
          flex: 3,
          child: _buildMainContent(card),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(CreditCard card) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: _buildCardImage(card)),
        const SizedBox(height: 32),
        _buildMainContent(card),
        const SizedBox(height: 40),
        _buildActionButtons(card),
      ],
    );
  }

  Widget _buildCardImage(CreditCard card) {
    return Hero(
      tag: card.id,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: card.imagePath.startsWith('http')
              ? Image.network(card.imagePath, fit: BoxFit.contain)
              : Image.asset(card.imagePath, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _buildMainContent(CreditCard card) {
    // Tự động tạo chips từ dữ liệu cashback thực tế
    final cashbackChips = [
      if ((card.supermarketCashbackRate ?? 0) > 0) 'Hoàn ${card.supermarketCashbackRate}% Siêu thị',
      if ((card.onlineCashbackRate ?? 0) > 0) 'Hoàn ${card.onlineCashbackRate}% Online',
      if ((card.diningCashbackRate ?? 0) > 0) 'Hoàn ${card.diningCashbackRate}% Ẩm thực',
      if ((card.travelCashbackRate ?? 0) > 0) 'Hoàn ${card.travelCashbackRate}% Du lịch',
      if ((card.shoppingCashbackRate ?? 0) > 0) 'Hoàn ${card.shoppingCashbackRate}% Mua sắm',
      if ((card.transportCashbackRate ?? 0) > 0) 'Hoàn ${card.transportCashbackRate}% Di chuyển',
      if ((card.educationCashbackRate ?? 0) > 0) 'Hoàn ${card.educationCashbackRate}% Giáo dục',
      if ((card.medicalCashbackRate ?? 0) > 0) 'Hoàn ${card.medicalCashbackRate}% Y tế',
      if ((card.insuranceCashbackRate ?? 0) > 0) 'Hoàn ${card.insuranceCashbackRate}% Bảo hiểm',
      if ((card.utilitiesCashbackRate ?? 0) > 0) 'Hoàn ${card.utilitiesCashbackRate}% Hóa đơn',
      if ((card.gymCashbackRate ?? 0) > 0) 'Hoàn ${card.gymCashbackRate}% Gym',
      if ((card.otherCashbackRate ?? 0) > 0) 'Hoàn ${card.otherCashbackRate}% Chi tiêu khác',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(card.name, style: AppStyles.h1.copyWith(fontSize: 28)),
        const SizedBox(height: 8),
        Text(card.bankName, style: AppStyles.bodyMedium.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),

        Text('ƯU ĐÃI HOÀN TIỀN NỔI BẬT', style: AppStyles.labelSmall.copyWith(letterSpacing: 1, color: AppColors.textLight)),
        const SizedBox(height: 12),
        // Highlights Chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (card.cashbackHighlight.isNotEmpty)
              _buildHighlightChip(card.cashbackHighlight),
            ...cashbackChips.map((text) => _buildHighlightChip(text, isSecondary: true)),
          ],
        ),
        const SizedBox(height: 48),
        
        // Tab Selector
        _buildTabSelector(),
        
        const SizedBox(height: 24),
        
        // Tab Content
        _buildTabContent(card),
      ],
    );
  }

  Widget _buildHighlightChip(String text, {bool isSecondary = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSecondary ? const Color(0xFFF7F3EE) : AppColors.accentOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isSecondary ? AppColors.border : AppColors.accentOrange.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        text,
        style: AppStyles.labelSmall.copyWith(
          color: isSecondary ? AppColors.textPrimary : AppColors.accentOrange,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    final tabs = ['Lợi ích', 'Điều kiện', 'Thông tin thẻ', 'Biểu phí'];
    return Container(
      height: 50,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedTabIndex == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedTabIndex = index),
            child: Container(
              margin: const EdgeInsets.only(right: 24),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: isSelected 
                  ? const Border(bottom: BorderSide(color: AppColors.primary, width: 3))
                  : null,
              ),
              child: Text(
                tabs[index],
                style: AppStyles.bodyMedium.copyWith(
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabContent(CreditCard card) {
    List<Map<String, String>>? data;
    switch (_selectedTabIndex) {
      case 0: data = card.benefitsDetail; break;
      case 1: data = card.conditionsDetail; break;
      case 2: data = card.productInfoDetail; break;
      case 3: data = card.feeDetail; break;
    }

    if (data == null || data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text('Thông tin đang được cập nhật...', style: AppStyles.bodyMedium),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: data.map((item) => _buildDetailItem(item['title'] ?? '', item['content'] ?? '')).toList(),
    );
  }

  Widget _buildDetailItem(String title, String content) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppStyles.h2.copyWith(fontSize: 18, color: AppColors.primary)),
          const SizedBox(height: 12),
          Text(content, style: AppStyles.bodyMedium.copyWith(height: 1.6, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(CreditCard card) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () => _launchUrl(card.applyUrl),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text('Mở thẻ ngay tại ${card.bankName}', style: AppStyles.buttonText),
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
                SnackBar(content: Text('Đã thêm ${card.name} vào so sánh')),
              );
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Thêm vào danh sách so sánh', 
              style: AppStyles.buttonText.copyWith(color: AppColors.primary)),
          ),
        ),
      ],
    );
  }

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể mở liên kết')),
        );
      }
    }
  }
}
