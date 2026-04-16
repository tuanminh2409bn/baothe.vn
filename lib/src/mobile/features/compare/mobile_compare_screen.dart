import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../constants/app_styles.dart';
import '../../../models/user_card_model.dart';
import '../../../services/firestore_service.dart';
import '../../../services/auth_service.dart';

class MobileCompareScreen extends ConsumerStatefulWidget {
  const MobileCompareScreen({super.key});

  @override
  ConsumerState<MobileCompareScreen> createState() => _MobileCompareScreenState();
}

class _MobileCompareScreenState extends ConsumerState<MobileCompareScreen> {
  UserCard? _card1;
  UserCard? _card2;

  final List<Map<String, String>> _compareCategories = [
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
    {'id': 'otherCashbackRate', 'label': 'Chi tiêu khác'},
  ];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authServiceProvider).currentUser;
    final userCardsAsync = user != null
        ? ref.watch(userCardsStreamProvider(user.uid))
        : const AsyncValue<List<UserCard>>.data([]);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'SO SÁNH THẺ',
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
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
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildAddCardSlot(context, _card1, (c) => setState(() => _card1 = c), userCardsAsync)),
                const SizedBox(width: 16),
                Expanded(child: _buildAddCardSlot(context, _card2, (c) => setState(() => _card2 = c), userCardsAsync)),
              ],
            ),
            const SizedBox(height: 32),
            if (_card1 != null && _card2 != null)
              _buildCompareTable()
            else
              _buildEmptyState(),
          ],
        ),
      ),
    );
  }

  Widget _buildAddCardSlot(BuildContext context, UserCard? selectedCard, Function(UserCard) onSelected, AsyncValue<List<UserCard>> cardsAsync) {
    return GestureDetector(
      onTap: () => _showCardSelectionDialog(context, cardsAsync, onSelected),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selectedCard != null ? AppColors.primary : Colors.grey.shade200, width: selectedCard != null ? 2 : 1),
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
                            selectedCard.cardName,
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
                  const Icon(Icons.add_circle_outline_rounded, size: 32, color: AppColors.primary),
                  const SizedBox(height: 8),
                  Text('Thêm thẻ', style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ],
              ),
      ),
    );
  }

  void _showCardSelectionDialog(BuildContext context, AsyncValue<List<UserCard>> cardsAsync, Function(UserCard) onSelected) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text('CHỌN THẺ TRONG VÍ', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            Expanded(
              child: cardsAsync.when(
                data: (cards) {
                  if (cards.isEmpty) return const Center(child: Text('Bạn chưa có thẻ nào trong ví.'));
                  return ListView.builder(
                    itemCount: cards.length,
                    itemBuilder: (context, index) {
                      final card = cards[index];
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: card.imagePath.startsWith('http')
                              ? Image.network(card.imagePath, width: 48, height: 32, fit: BoxFit.cover)
                              : Image.asset(card.imagePath, width: 48, height: 32, fit: BoxFit.cover),
                        ),
                        title: Text(card.cardName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(card.bankName),
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
    );
  }

  Widget _buildCompareTable() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Expanded(flex: 3, child: SizedBox()),
              Expanded(
                flex: 2,
                child: Text(
                  _card1!.cardName,
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  _card2!.cardName,
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ..._compareCategories.map((cat) {
          final rate1 = _getCashbackRate(_card1!, cat['id']!);
          final rate2 = _getCashbackRate(_card2!, cat['id']!);
          final isBest1 = rate1 > rate2 && rate1 > 0;
          final isBest2 = rate2 > rate1 && rate2 > 0;

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
                    style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isBest1 ? Colors.green.shade50 : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${rate1.toStringAsFixed(1)}%',
                      style: GoogleFonts.inter(
                        color: isBest1 ? Colors.green.shade700 : AppColors.textPrimary,
                        fontWeight: isBest1 ? FontWeight.w900 : FontWeight.normal,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isBest2 ? Colors.green.shade50 : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${rate2.toStringAsFixed(1)}%',
                      style: GoogleFonts.inter(
                        color: isBest2 ? Colors.green.shade700 : AppColors.textPrimary,
                        fontWeight: isBest2 ? FontWeight.w900 : FontWeight.normal,
                        fontSize: 14,
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

  double _getCashbackRate(UserCard card, String categoryId) {
    switch (categoryId) {
      case 'supermarketCashbackRate': return card.supermarketCashbackRate ?? 0;
      case 'onlineCashbackRate': return card.onlineCashbackRate ?? 0;
      case 'travelCashbackRate': return card.travelCashbackRate ?? 0;
      case 'diningCashbackRate': return card.diningCashbackRate ?? 0;
      case 'medicalCashbackRate': return card.medicalCashbackRate ?? 0;
      case 'educationCashbackRate': return card.educationCashbackRate ?? 0;
      case 'transportCashbackRate': return card.transportCashbackRate ?? 0;
      case 'shoppingCashbackRate': return card.shoppingCashbackRate ?? 0;
      case 'insuranceCashbackRate': return card.insuranceCashbackRate ?? 0;
      case 'utilitiesCashbackRate': return card.utilitiesCashbackRate ?? 0;
      case 'entertainmentCashbackRate': return card.entertainmentCashbackRate ?? 0;
      case 'gymCashbackRate': return card.gymCashbackRate ?? 0;
      case 'otherCashbackRate': return card.otherCashbackRate ?? 0;
      default: return 0;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          Icon(Icons.compare_arrows_rounded, size: 64, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text(
            'Chưa có dữ liệu so sánh',
            style: GoogleFonts.inter(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Vui lòng chọn 2 thẻ để thấy sự khác biệt về ưu đãi hoàn tiền.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppColors.textLight, fontSize: 13),
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}
