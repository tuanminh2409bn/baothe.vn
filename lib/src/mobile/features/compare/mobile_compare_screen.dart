import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_styles.dart';
import '../../../models/credit_card_model.dart';
import '../../../services/firestore_service.dart';

class MobileCompareScreen extends ConsumerStatefulWidget {
  const MobileCompareScreen({super.key});

  @override
  ConsumerState<MobileCompareScreen> createState() => _MobileCompareScreenState();
}

class _MobileCompareScreenState extends ConsumerState<MobileCompareScreen> {
  CreditCard? _card1;
  CreditCard? _card2;

  final List<Map<String, String>> _compareCategories = [
    {'id': 'annualFee', 'label': 'Phí thường niên'},
    {'id': 'interestRate', 'label': 'Lãi suất'},
    {'id': 'cardTier', 'label': 'Hạng thẻ'},
    {'id': 'supermarketCashbackRate', 'label': 'Siêu thị'},
    {'id': 'diningCashbackRate', 'label': 'Ẩm thực'},
    {'id': 'onlineCashbackRate', 'label': 'Online/Mua sắm'},
    {'id': 'travelCashbackRate', 'label': 'Du lịch'},
    {'id': 'transportCashbackRate', 'label': 'Di chuyển'},
    {'id': 'medicalCashbackRate', 'label': 'Y tế'},
    {'id': 'educationCashbackRate', 'label': 'Giáo dục'},
    {'id': 'gymCashbackRate', 'label': 'Gym/Thể thao'},
    {'id': 'insuranceCashbackRate', 'label': 'Bảo hiểm'},
    {'id': 'utilitiesCashbackRate', 'label': 'Tiện ích/Hóa đơn'},
    {'id': 'entertainmentCashbackRate', 'label': 'Giải trí'},
    {'id': 'otherCashbackRate', 'label': 'Hoàn tiền chi tiêu'},
    {'id': 'maxCashbackPerMonth', 'label': 'Hoàn tiền tối đa'},
  ];

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(cardsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary(context)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'SO SÁNH THẺ',
          style: GoogleFonts.inter(
            color: AppColors.textPrimary(context),
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CHỌN THẺ ĐỂ ĐỐI CHIẾU',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: AppColors.textSecondary(context),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildAddCardSlot(context, _card1, (c) => setState(() => _card1 = c), cardsAsync)),
                const SizedBox(width: 16),
                Expanded(child: _buildAddCardSlot(context, _card2, (c) => setState(() => _card2 = c), cardsAsync)),
              ],
            ),
            const SizedBox(height: 32),
            if (_card1 != null && _card2 != null)
              _buildCompareTable(context)
            else
              _buildEmptyState(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAddCardSlot(BuildContext context, CreditCard? selectedCard, Function(CreditCard) onSelected, AsyncValue<List<CreditCard>> cardsAsync) {
    return GestureDetector(
      onTap: () => _showCardSelectionDialog(context, cardsAsync, onSelected),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selectedCard != null ? AppColors.primary(context) : Colors.grey.shade200, width: selectedCard != null ? 2 : 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: selectedCard != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    if (selectedCard.imagePath.isNotEmpty)
                      Positioned.fill(
                        child: selectedCard.imagePath.startsWith('http')
                            ? Image.network(selectedCard.imagePath, fit: BoxFit.cover)
                            : Image.asset(selectedCard.imagePath, fit: BoxFit.cover),
                      ),
                    Positioned.fill(child: Container(color: Colors.black26)),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedCard.name,
                            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            selectedCard.bankName,
                            style: GoogleFonts.inter(color: Colors.white70, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        icon: const Icon(Icons.change_circle_rounded, color: Colors.white),
                        onPressed: () => _showCardSelectionDialog(context, cardsAsync, onSelected),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline_rounded, size: 32, color: AppColors.primary(context)),
                  const SizedBox(height: 8),
                  Text('Thêm thẻ', style: GoogleFonts.inter(color: AppColors.primary(context), fontWeight: FontWeight.bold)),
                ],
              ),
      ),
    );
  }

  void _showCardSelectionDialog(BuildContext context, AsyncValue<List<CreditCard>> cardsAsync, Function(CreditCard) onSelected) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.border(context), borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 24),
              Text('CHỌN THẺ ĐỂ SO SÁNH', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              Expanded(
                child: cardsAsync.when(
                  data: (cards) {
                    if (cards.isEmpty) return const Center(child: Text('Không có dữ liệu thẻ.'));
                    return ListView.separated(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      itemCount: cards.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final card = cards[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: card.imagePath.startsWith('http')
                                ? Image.network(card.imagePath, width: 48, height: 32, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.credit_card))
                                : Image.asset(card.imagePath, width: 48, height: 32, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.credit_card)),
                          ),
                          title: Text(card.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(card.bankName, style: const TextStyle(fontSize: 12)),
                          onTap: () {
                            onSelected(card);
                            Navigator.pop(context);
                          },
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, _) => const Center(child: Text('Lỗi tải thẻ')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompareTable(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.primary(context),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Expanded(flex: 3, child: SizedBox()),
              Expanded(
                flex: 2,
                child: Text(
                  _card1!.name,
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Text(
                  _card2!.name,
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ..._compareCategories.map((cat) {
          final val1 = _getCategoryValue(_card1!, cat['id']!);
          final val2 = _getCategoryValue(_card2!, cat['id']!);
          
          final isBest1 = _isBetter(val1, val2, cat['id']!);
          final isBest2 = _isBetter(val2, val1, cat['id']!);

          return Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    cat['label']!,
                    style: GoogleFonts.inter(color: AppColors.textSecondary(context), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    decoration: BoxDecoration(
                      color: isBest1 ? Colors.green.shade50 : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatValue(val1, cat['id']!),
                      style: GoogleFonts.inter(
                        color: isBest1 ? Colors.green.shade700 : AppColors.textPrimary(context),
                        fontWeight: isBest1 ? FontWeight.w900 : FontWeight.normal,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    decoration: BoxDecoration(
                      color: isBest2 ? Colors.green.shade50 : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatValue(val2, cat['id']!),
                      style: GoogleFonts.inter(
                        color: isBest2 ? Colors.green.shade700 : AppColors.textPrimary(context),
                        fontWeight: isBest2 ? FontWeight.w900 : FontWeight.normal,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 50.ms).slideX(begin: 0.1);
        }),
      ],
    );
  }

  dynamic _getCategoryValue(CreditCard card, String categoryId) {
    switch (categoryId) {
      case 'annualFee': return card.annualFee ?? 0.0;
      case 'interestRate': return card.interestRate ?? 0.0;
      case 'cardTier': return card.cardTier ?? 'Thường';
      case 'supermarketCashbackRate': return card.supermarketCashbackRate ?? 0.0;
      case 'onlineCashbackRate': return card.onlineCashbackRate ?? 0.0;
      case 'travelCashbackRate': return card.travelCashbackRate ?? 0.0;
      case 'diningCashbackRate': return card.diningCashbackRate ?? 0.0;
      case 'medicalCashbackRate': return card.medicalCashbackRate ?? 0.0;
      case 'educationCashbackRate': return card.educationCashbackRate ?? 0.0;
      case 'transportCashbackRate': return card.transportCashbackRate ?? 0.0;
      case 'shoppingCashbackRate': return card.shoppingCashbackRate ?? 0.0;
      case 'insuranceCashbackRate': return card.insuranceCashbackRate ?? 0.0;
      case 'utilitiesCashbackRate': return card.utilitiesCashbackRate ?? 0.0;
      case 'entertainmentCashbackRate': return card.entertainmentCashbackRate ?? 0.0;
      case 'gymCashbackRate': return card.gymCashbackRate ?? 0.0;
      case 'otherCashbackRate': return card.otherCashbackRate ?? 0.0;
      case 'maxCashbackPerMonth': return card.maxCashbackPerMonth ?? 0.0;
      default: return 0.0;
    }
  }

  bool _isBetter(dynamic val1, dynamic val2, String categoryId) {
    if (val1 is double && val2 is double) {
      if (categoryId == 'annualFee' || categoryId == 'interestRate') {
        // Phí và Lãi suất càng thấp càng tốt, nhưng 0 có thể là "Chưa rõ"
        if (val1 == 0) return false;
        if (val2 == 0) return true;
        return val1 < val2;
      }
      // Các loại hoàn tiền càng cao càng tốt
      return val1 > val2 && val1 > 0;
    }
    return false;
  }

  String _formatValue(dynamic val, String categoryId) {
    if (val is double) {
      if (val == 0) return '-';
      if (categoryId == 'annualFee' || categoryId == 'maxCashbackPerMonth') {
        if (val >= 1000000) {
          return '${(val / 1000000).toStringAsFixed(1)}M';
        } else if (val >= 1000) {
          return '${(val / 1000).toStringAsFixed(0)}K';
        }
        return NumberFormat.currency(locale: 'vi_VN', symbol: '').format(val).trim();
      }
      return '${val.toStringAsFixed(1)}%';
    }
    return val.toString();
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          Icon(Icons.compare_arrows_rounded, size: 64, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text(
            'Chưa có dữ liệu so sánh',
            style: GoogleFonts.inter(color: AppColors.textSecondary(context), fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Vui lòng chọn 2 thẻ từ tất cả các thẻ để thấy sự khác biệt.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppColors.textLight(context), fontSize: 13),
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}
