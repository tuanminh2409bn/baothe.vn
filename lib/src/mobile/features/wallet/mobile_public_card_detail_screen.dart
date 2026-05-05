import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_styles.dart';
import '../../../models/credit_card_model.dart';
import 'package:url_launcher/url_launcher.dart';

class MobilePublicCardDetailScreen extends ConsumerWidget {
  final CreditCard creditCard;

  const MobilePublicCardDetailScreen({super.key, required this.creditCard});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHero(context),
            const SizedBox(height: 24),
            _buildCashbackGrid(creditCard),
            const SizedBox(height: 32),
            _buildCardBenefits(context, creditCard),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () async {
                if (creditCard.applyUrl.isNotEmpty) {
                  final url = Uri.parse(creditCard.applyUrl);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary(context),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(
                'ĐĂNG KÝ THẺ',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardHero(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            if (creditCard.imagePath.isNotEmpty)
              Positioned.fill(
                child: creditCard.imagePath.startsWith('http')
                    ? Image.network(creditCard.imagePath, fit: BoxFit.cover, alignment: Alignment.center)
                    : Image.asset(creditCard.imagePath, fit: BoxFit.cover, alignment: Alignment.center),
              ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    creditCard.name,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    creditCard.bankName,
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
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
            final materialColor = cat['color'] is MaterialColor 
              ? (cat['color'] as MaterialColor) 
              : Colors.blue;
              
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
                      color: materialColor.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(cat['icon'] as IconData, color: materialColor.shade600, size: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${cat['rate']}%',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14, color: materialColor.shade700),
                  ),
                  Text(
                    cat['label'] as String,
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary(context)),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCardBenefits(BuildContext context, CreditCard card) {
    if (card.benefits == null || card.benefits!.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tiện ích thẻ', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Column(
            children: card.benefits!.map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_rounded, size: 18, color: AppColors.primary(context)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(b, style: GoogleFonts.inter(fontSize: 13, height: 1.5, color: AppColors.textPrimary(context))),
                  ),
                ],
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }
}
