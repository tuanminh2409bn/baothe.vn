import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_styles.dart';
import '../../../services/firestore_service.dart';
import '../../../models/user_card_model.dart';
import '../../../models/credit_card_model.dart';

class MobileCardDetailScreen extends ConsumerWidget {
  final UserCard userCard;

  const MobileCardDetailScreen({super.key, required this.userCard});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Lấy thông tin gốc của thẻ từ firestore (lúc bóc tách dữ liệu)
    final cardDetailAsync = ref.watch(cardDetailProvider(userCard.cardId));

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'CHI TIẾT THẺ',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            onPressed: () => _confirmDeleteCard(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHero(),
            const SizedBox(height: 24),
            _buildFinancialSummary(),
            const SizedBox(height: 32),
            cardDetailAsync.when(
              data: (creditCard) {
                if (creditCard == null) {
                  return const Center(child: Text('Không tìm thấy thông tin gốc của thẻ này.'));
                }
                return _buildCardBenefits(creditCard);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => Center(child: Text('Lỗi tải dữ liệu thẻ: $err')),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteCard(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Gỡ thẻ khỏi ví', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Bạn có chắc chắn muốn gỡ thẻ ${userCard.cardName} khỏi tài khoản? Lịch sử giao dịch liên quan có thể không hiển thị đúng.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Hủy', style: GoogleFonts.inter(color: AppColors.textLight)),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement actual delete logic in firestore_service if needed in future,
              // For now, just pop back with a mock message since full delete involves transactions cleanup.
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chức năng xoá thẻ đang được cập nhật!')));
            },
            child: Text('Gỡ thẻ', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCardHero() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
        image: DecorationImage(
          image: NetworkImage(userCard.imagePath),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.2), BlendMode.darken),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                userCard.bankName,
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Icon(Icons.contactless_outlined, color: Colors.white),
            ],
          ),
          Text(
            userCard.cardName,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary() {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final available = userCard.limit - userCard.balance;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStat('Hạn mức', currencyFormat.format(userCard.limit), AppColors.textPrimary),
          Container(width: 1, height: 40, color: const Color(0xFFF3F4F6)),
          _buildStat('Khả dụng', currencyFormat.format(available), Colors.green),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildCardBenefits(CreditCard card) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (card.cashbackHighlight.isNotEmpty) ...[
          _buildHighlightCard(Icons.local_offer_rounded, 'Khuyến mãi nổi bật', card.cashbackHighlight, Colors.orange),
          const SizedBox(height: 16),
        ],
        
        if (card.promoHighlight != null && card.promoHighlight!.isNotEmpty) ...[
          _buildHighlightCard(Icons.star_rounded, 'Chương trình đặc biệt', card.promoHighlight!, Colors.purple),
          const SizedBox(height: 24),
        ],

        Text('Quyền lợi chính', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        
        if (card.benefits != null && card.benefits!.isNotEmpty)
          ...card.benefits!.map((b) => _buildBenefitItem(b)),
          
        if (card.benefits == null || card.benefits!.isEmpty)
          Text('Thẻ này hiện không có mô tả quyền lợi', style: GoogleFonts.inter(color: AppColors.textLight, fontStyle: FontStyle.italic)),

        const SizedBox(height: 32),
        
        if (card.benefitsDetail != null && card.benefitsDetail!.isNotEmpty)
          _buildDetailAccordion('Chi tiết ưu đãi', Icons.card_giftcard_rounded, card.benefitsDetail!),
          
        if (card.conditionsDetail != null && card.conditionsDetail!.isNotEmpty)
          _buildDetailAccordion('Điều kiện mở thẻ', Icons.gavel_rounded, card.conditionsDetail!),
          
        if (card.feeDetail != null && card.feeDetail!.isNotEmpty)
          _buildDetailAccordion('Biểu phí dịch vụ', Icons.receipt_long_rounded, card.feeDetail!),
      ],
    );
  }

  Widget _buildHighlightCard(IconData icon, String title, String content, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color.shade700, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: color.shade800)),
                const SizedBox(height: 4),
                Text(content, style: GoogleFonts.inter(fontSize: 14, color: color.shade900)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: GoogleFonts.inter(fontSize: 14, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailAccordion(String title, IconData icon, List<Map<String, String>> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: AppColors.primary,
          collapsedIconColor: AppColors.textLight,
          leading: Icon(icon, color: AppColors.primary),
          title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: items.map((item) {
            String subTitle = item.keys.first;
            String desc = item.values.first;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subTitle, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(desc, style: GoogleFonts.inter(fontSize: 13, height: 1.5, color: AppColors.textPrimary)),
                  const Divider(height: 16, color: Color(0xFFF9FAFB)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
