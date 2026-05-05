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
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'CHI TIẾT THẺ',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppColors.textPrimary(context)),
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
            _buildCardHero(context),
            const SizedBox(height: 24),
            _buildFinancialSummary(context),
            const SizedBox(height: 24),
            cardDetailAsync.when(
              data: (creditCard) {
                if (creditCard == null) {
                  return const Center(child: Text('Không tìm thấy thông tin gốc của thẻ này.'));
                }
                return Column(
                  children: [
                    _buildCashbackGrid(creditCard),
                    const SizedBox(height: 32),
                    _buildCardBenefits(context, creditCard),
                  ],
                );
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

  Widget _buildCashbackGrid(CreditCard card) {
    final categories = [
      {'label': 'Siêu thị', 'rate': card.supermarketCashbackRate, 'icon': Icons.shopping_basket_rounded, 'color': Colors.green},
      {'label': 'Online', 'rate': card.onlineCashbackRate, 'icon': Icons.language_rounded, 'color': Colors.blue},
      {'label': 'Ẩm thực', 'rate': card.diningCashbackRate, 'icon': Icons.restaurant_rounded, 'color': Colors.orange},
      {'label': 'Di chuyển', 'rate': card.transportCashbackRate, 'icon': Icons.directions_car_rounded, 'color': Colors.indigo},
      {'label': 'Du lịch', 'rate': card.travelCashbackRate, 'icon': Icons.flight_rounded, 'color': Colors.teal},
      {'label': 'Y tế', 'rate': card.medicalCashbackRate, 'icon': Icons.medical_services_rounded, 'color': Colors.red},
      {'label': 'Giáo dục', 'rate': card.educationCashbackRate, 'icon': Icons.school_rounded, 'color': Colors.brown},
      {'label': 'Mua sắm', 'rate': card.shoppingCashbackRate, 'icon': Icons.shopping_bag_rounded, 'color': Colors.pink},
      {'label': 'Hóa đơn', 'rate': card.utilitiesCashbackRate, 'icon': Icons.receipt_rounded, 'color': Colors.amber},
      {'label': 'Giải trí', 'rate': card.entertainmentCashbackRate, 'icon': Icons.movie_rounded, 'color': Colors.deepPurple},
      {'label': 'Gym', 'rate': card.gymCashbackRate, 'icon': Icons.fitness_center_rounded, 'color': Colors.blueGrey},
      {'label': 'Bảo hiểm', 'rate': card.insuranceCashbackRate, 'icon': Icons.security_rounded, 'color': Colors.cyan},
      {'label': 'Chi tiêu', 'rate': card.otherCashbackRate, 'icon': Icons.more_horiz_rounded, 'color': Colors.grey},
    ].where((cat) => (cat['rate'] as double? ?? 0) > 0).toList();

    if (categories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Hoàn tiền theo hạng mục', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
            if (card.maxCashbackPerMonth != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Max ${NumberFormat.compactCurrency(locale: 'vi_VN', symbol: 'đ').format(card.maxCashbackPerMonth)}/tháng',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.9,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border(context)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (cat['color'] as MaterialColor).shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(cat['icon'] as IconData, color: (cat['color'] as MaterialColor).shade600, size: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(cat['label'] as String, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textLight(context))),
                  const SizedBox(height: 2),
                  Text('${cat['rate']}%', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
                ],
              ),
            );
          },
        ),
      ],
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
            child: Text('Hủy', style: GoogleFonts.inter(color: AppColors.textLight(context))),
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

  Widget _buildCardHero(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.primary(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary(context).withValues(alpha: 0.3),
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

  Widget _buildFinancialSummary(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final available = userCard.limit - userCard.balance;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStat(context, 'Hạn mức', currencyFormat.format(userCard.limit), AppColors.textPrimary(context)),
          Container(width: 1, height: 40, color: AppColors.border(context)),
          _buildStat(context, 'Khả dụng', currencyFormat.format(available), Colors.green),
        ],
      ),
    );
  }

  Widget _buildStat(BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight(context))),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildCardBenefits(BuildContext context, CreditCard card) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (card.cashbackHighlight.isNotEmpty) ...[
          _buildHighlightCard(context, Icons.local_offer_rounded, 'Khuyến mãi nổi bật', card.cashbackHighlight, Colors.orange),
          const SizedBox(height: 16),
        ],
        
        if (card.promoHighlight != null && card.promoHighlight!.isNotEmpty) ...[
          _buildHighlightCard(context, Icons.star_rounded, 'Chương trình đặc biệt', card.promoHighlight!, Colors.purple),
          const SizedBox(height: 24),
        ],

        Text('Quyền lợi chính', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        
        if (card.benefits != null && card.benefits!.isNotEmpty)
          ...card.benefits!.map((b) => _buildBenefitItem(context, b)),
          
        if (card.benefits == null || card.benefits!.isEmpty)
          Text('Thẻ này hiện không có mô tả quyền lợi', style: GoogleFonts.inter(color: AppColors.textLight(context), fontStyle: FontStyle.italic)),

        const SizedBox(height: 32),
        
        if (card.benefitsDetail != null && card.benefitsDetail!.isNotEmpty)
          _buildDetailAccordion(context, 'Chi tiết ưu đãi', Icons.card_giftcard_rounded, card.benefitsDetail!),
          
        if (card.conditionsDetail != null && card.conditionsDetail!.isNotEmpty)
          _buildDetailAccordion(context, 'Điều kiện mở thẻ', Icons.gavel_rounded, card.conditionsDetail!),
          
        if (card.feeDetail != null && card.feeDetail!.isNotEmpty)
          _buildDetailAccordion(context, 'Biểu phí dịch vụ', Icons.receipt_long_rounded, card.feeDetail!),
      ],
    );
  }

  Widget _buildHighlightCard(BuildContext context, IconData icon, String title, String content, MaterialColor color) {
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

  Widget _buildBenefitItem(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.check_circle_rounded, color: AppColors.primary(context), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: GoogleFonts.inter(fontSize: 14, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailAccordion(BuildContext context, String title, IconData icon, List<Map<String, String>> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: AppColors.primary(context),
          collapsedIconColor: AppColors.textLight(context),
          leading: Icon(icon, color: AppColors.primary(context)),
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
                  Text(subTitle, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary(context))),
                  const SizedBox(height: 4),
                  Text(desc, style: GoogleFonts.inter(fontSize: 13, height: 1.5, color: AppColors.textPrimary(context))),
                  Divider(height: 16, color: AppColors.background(context)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
