import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../constants/app_styles.dart';
import '../../common_widgets/animated_hover.dart';
import '../../models/credit_card_model.dart';
import '../../services/firestore_service.dart';

// Bộ định dạng phân tách phần nghìn khi nhập liệu
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  static const separator = '.'; // Dùng dấu chấm cho định dạng VN

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '0');
    }

    // Chỉ lấy các chữ số
    String text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Loại bỏ số 0 ở đầu nếu có nhiều chữ số
    if (text.length > 1 && text.startsWith('0')) {
      text = text.substring(1);
    }

    if (text.isEmpty) return oldValue;

    // Định dạng lại chuỗi với dấu phân cách
    final formatter = NumberFormat("#,###", "vi_VN");
    String newText = formatter.format(int.parse(text)).replaceAll(',', separator);

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class CalculatorScreen extends ConsumerStatefulWidget {
  const CalculatorScreen({super.key});

  @override
  ConsumerState<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends ConsumerState<CalculatorScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  final Map<String, TextEditingController> _controllers = {};
  final currencyFormatter = NumberFormat("#,###", "vi_VN");
  
  List<Map<String, dynamic>> _topCards = [];
  bool _isCalculated = false;

  final List<Map<String, dynamic>> _categories = [
    {'icon': Icons.mic, 'label': 'GIẢI TRÍ', 'keywords': ['giải trí', 'xem phim', 'cinema', 'netflix', 'spotify']},
    {'icon': Icons.fitness_center, 'label': 'FITNESS', 'keywords': ['fitness', 'gym', 'tập luyện', 'thể thao']},
    {'icon': Icons.spa, 'label': 'SPA/LÀM ĐẸP', 'keywords': ['spa', 'làm đẹp', 'beauty', 'cosmetic', 'mỹ phẩm']},
    {'icon': Icons.shopping_bag, 'label': 'MUA SẮM', 'keywords': ['mua sắm', 'shopping', 'trung tâm thương mại']},
    {'icon': Icons.flight, 'label': 'DU LỊCH', 'keywords': ['du lịch', 'travel', 'vé máy bay', 'khách sạn', 'hotel', 'resort', 'phòng chờ']},
    {'icon': Icons.directions_car, 'label': 'GRAB', 'keywords': ['grab']},
    {'icon': Icons.eco, 'label': 'XANH SM', 'keywords': ['xanh sm']},
    {'icon': Icons.shopping_cart, 'label': 'TIKI', 'keywords': ['tiki']},
    {'icon': Icons.music_note, 'label': 'TIKTOK SHOP', 'keywords': ['tiktok shop']},
    {'icon': Icons.favorite, 'label': 'SHOPEE', 'keywords': ['shopee']},
    {'icon': Icons.card_giftcard, 'label': 'LAZADA', 'keywords': ['lazada']},
    {'icon': Icons.fastfood, 'label': 'ĂN UỐNG', 'keywords': ['ăn uống', 'ẩm thực', 'nhà hàng', 'dining']},
    {'icon': Icons.local_pizza, 'label': 'SHOPEEFOOD', 'keywords': ['shopeefood']},
    {'icon': Icons.local_grocery_store, 'label': 'SIÊU THỊ', 'keywords': ['siêu thị', 'lotte mart', 'winmart', 'coop mart']},
    {'icon': Icons.school, 'label': 'GIÁO DỤC', 'keywords': ['giáo dục', 'học phí', 'trường học']},
    {'icon': Icons.local_hospital, 'label': 'Y TẾ', 'keywords': ['y tế', 'bệnh viện', 'thuốc', 'pharmacy']},
    {'icon': Icons.shield, 'label': 'BẢO HIỂM', 'keywords': ['bảo hiểm', 'insurance']},
    {'icon': Icons.motorcycle, 'label': 'BE', 'keywords': ['be']},
    {'icon': Icons.bed, 'label': 'PHÒNG CHỜ', 'keywords': ['phòng chờ', 'lounge']},
    {'icon': Icons.more_horiz, 'label': 'KHÁC', 'keywords': []},
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _startTimer();
    for (var cat in _categories) {
      _controllers[cat['label']] = TextEditingController(text: '0');
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_currentPage < 3) _currentPage++; else _currentPage = 0;
      if (_pageController.hasClients) {
        _pageController.animateToPage(_currentPage, duration: const Duration(milliseconds: 1000), curve: Curves.easeInOut);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    for (var controller in _controllers.values) controller.dispose();
    super.dispose();
  }

  void _calculateCashback(List<CreditCard> allCards) {
    List<Map<String, dynamic>> results = [];
    double totalSpending = 0;

    for (var cat in _categories) {
      double spending = double.tryParse(_controllers[cat['label']]!.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
      totalSpending += spending;
    }

    if (totalSpending <= 0) {
      setState(() => _isCalculated = false);
      return;
    }

    for (var card in allCards) {
      double totalCashback = 0;
      List<String> matchedCategories = [];

      for (var cat in _categories) {
        String label = cat['label'];
        List<String> keywords = List<String>.from(cat['keywords']);
        double spending = double.tryParse(_controllers[label]!.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
        
        if (spending <= 0) continue;

        bool isMatch = false;
        String fullInfo = (card.name + card.cashbackHighlight + card.details.join(' ')).toLowerCase();
        if (card.benefitsDetail != null) {
          for (var b in card.benefitsDetail!) fullInfo += (b['title'] ?? '') + (b['content'] ?? '');
        }

        for (var kw in keywords) {
          if (fullInfo.contains(kw.toLowerCase())) {
            isMatch = true;
            break;
          }
        }

        double rate = isMatch ? 0.05 : 0.005; 
        if (card.name.contains('Online') && (label == 'SHOPEE' || label == 'TIKI' || label == 'LAZADA')) rate = 0.06;

        totalCashback += spending * rate;
        if (isMatch) matchedCategories.add(label);
      }

      if (totalCashback > 0) {
        results.add({'card': card, 'totalCashback': totalCashback, 'matchedCategories': matchedCategories});
      }
    }

    results.sort((a, b) => (b['totalCashback'] as double).compareTo(a['totalCashback'] as double));

    setState(() {
      _topCards = results.take(5).toList();
      _isCalculated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;
    final cardsAsync = ref.watch(cardsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            _buildBannerSlider(screenWidth),
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1400),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                child: Column(
                  children: [
                    Text('TÍNH TOÁN HOÀN TIỀN', textAlign: TextAlign.center, style: AppStyles.h1.copyWith(color: AppColors.primary, fontSize: isMobile ? 32 : 48, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text('Nhập chi tiết chi tiêu để tìm "chiến thần" hoàn tiền từ dữ liệu thật.', textAlign: TextAlign.center, style: AppStyles.h2.copyWith(color: AppColors.textSecondary, fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 50),
                    cardsAsync.when(
                      data: (cards) => isMobile
                        ? Column(children: [_buildInputForm(isMobile, () => _calculateCashback(cards)), const SizedBox(height: 40), _buildTop5Cards()])
                        : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 6, child: _buildInputForm(isMobile, () => _calculateCashback(cards))), const SizedBox(width: 40), Expanded(flex: 4, child: _buildTop5Cards())]),
                      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accentOrange)),
                      error: (err, _) => Center(child: Text('Lỗi: $err')),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 80, padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5))),
      child: Row(children: [InkWell(onTap: () => context.go('/'), child: Image.asset('assets/logo/logo.png', height: 45, fit: BoxFit.contain)), const Spacer(), _buildMenuItem('TRA CỨU', onTap: () => context.go('/')), _buildMenuItem('TÍNH TOÁN', isSelected: true)]),
    );
  }

  Widget _buildMenuItem(String title, {bool isSelected = false, VoidCallback? onTap}) {
    return AnimatedHover(scale: 1.02, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: Text(title, style: AppStyles.h2.copyWith(fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: isSelected ? AppColors.textPrimary : AppColors.textSecondary)))));
  }

  Widget _buildBannerSlider(double width) {
    double bannerWidth = width > 1480 ? 1400 : width - 80;
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 30), width: bannerWidth,
        child: AspectRatio(
          aspectRatio: 1400 / 500,
          child: Stack(
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(24), child: PageView(controller: _pageController, onPageChanged: (index) => _currentPage = index, children: [_buildSliderItem('assets/web/slider1.png'), _buildSliderItem('assets/web/slider2.png'), _buildSliderItem('assets/web/slider3.png'), _buildSliderItem('assets/web/slider4.png')])),
              Positioned(left: 20, top: 0, bottom: 0, child: Center(child: _buildSliderButton(icon: Icons.arrow_back_ios_new, onTap: () => _pageController.previousPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOut)))),
              Positioned(right: 20, top: 0, bottom: 0, child: Center(child: _buildSliderButton(icon: Icons.arrow_forward_ios, onTap: () => _pageController.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOut)))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliderButton({required IconData icon, required VoidCallback onTap}) {
    return Material(color: Colors.black.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(30), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(30), child: Container(width: 45, height: 45, alignment: Alignment.center, child: Icon(icon, color: Colors.white, size: 18))));
  }

  Widget _buildSliderItem(String assetPath) {
    return Image.asset(assetPath, fit: BoxFit.contain, width: double.infinity);
  }

  Widget _buildInputForm(bool isMobile, VoidCallback onCalculate) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Color(0xFFF7F3EE), shape: BoxShape.circle), child: const Icon(Icons.calculate, color: AppColors.primary, size: 30)), const SizedBox(width: 15), Text('Chi tiêu tháng này (VNĐ)', style: AppStyles.h1.copyWith(fontSize: 24, color: AppColors.textPrimary))]),
          const SizedBox(height: 30),
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: isMobile ? 2 : 3, childAspectRatio: 2.2, crossAxisSpacing: 20, mainAxisSpacing: 20),
            itemCount: _categories.length,
            itemBuilder: (context, index) => _buildInputField(_categories[index]['icon'] as IconData, _categories[index]['label'] as String),
          ),
          const SizedBox(height: 40),
          AnimatedHover(scale: 1.02, child: SizedBox(width: double.infinity, height: 60, child: ElevatedButton(onPressed: onCalculate, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: Text('PHÂN TÍCH & TÌM THẺ THỰC TẾ', style: AppStyles.buttonText.copyWith(fontSize: 18, letterSpacing: 1, color: Colors.white))))),
        ],
      ),
    );
  }

  Widget _buildInputField(IconData icon, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Icon(icon, size: 16, color: AppColors.textSecondary), const SizedBox(width: 5), Flexible(child: Text(label, style: AppStyles.labelSmall.copyWith(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis))]),
        const SizedBox(height: 5),
        Expanded(
          child: TextField(
            controller: _controllers[label],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()],
            decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border, width: 1)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border, width: 1)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5))),
            style: AppStyles.bodyMedium.copyWith(fontSize: 14), keyboardType: TextInputType.number,
          ),
        ),
      ],
    );
  }

  Widget _buildTop5Cards() {
    if (!_isCalculated) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thẻ đề xuất (Mẫu)', style: AppStyles.h2.copyWith(fontSize: 20)),
          const SizedBox(height: 20),
          _buildMockResultCard('#1', 'VCB Vibe Platinum', 'Hoàn 20% Du lịch/Ẩm thực', '500.000đ', Colors.orange),
          const SizedBox(height: 15),
          _buildMockResultCard('#2', 'VIB Online Plus 2in1', 'Hoàn 6% Mua sắm Online', '300.000đ', Colors.blue),
          const SizedBox(height: 15),
          _buildMockResultCard('#3', 'HSBC Cashback', 'Hoàn 6% Siêu thị/Cửa hàng tiện lợi', '250.000đ', Colors.red),
          const SizedBox(height: 15),
          _buildMockResultCard('#4', 'Techcombank Signature', 'Hoàn tiền không giới hạn 1.1%', '200.000đ', Colors.black),
          const SizedBox(height: 15),
          _buildMockResultCard('#5', 'VPBank StepUp', 'Hoàn 15% cho Grab/Be/XanhSM', '150.000đ', Colors.green),
        ],
      );
    }

    if (_topCards.isEmpty) return const Center(child: Text('Không tìm thấy thẻ phù hợp.'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Top 5 thẻ đề xuất (Dữ liệu thật)', style: AppStyles.h2.copyWith(fontSize: 20)),
        const SizedBox(height: 20),
        ..._topCards.asMap().entries.map((entry) {
          final card = entry.value['card'] as CreditCard;
          final cashback = entry.value['totalCashback'] as double;
          final matched = entry.value['matchedCategories'] as List<String>;
          return Padding(padding: const EdgeInsets.only(bottom: 15), child: _buildRealResultCard('#${entry.key + 1}', card, matched.join(', '), currencyFormatter.format(cashback.toInt()) + 'đ'));
        }),
      ],
    );
  }

  Widget _buildMockResultCard(String rank, String name, String desc, String cashback, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border.withValues(alpha: 0.5))),
      child: Row(children: [
        Text(rank, style: AppStyles.h1.copyWith(color: const Color(0xFFD1D5DB), fontSize: 24)),
        const SizedBox(width: 15),
        Container(width: 50, height: 35, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 15),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: AppStyles.h2.copyWith(fontSize: 16)), Text(desc, style: AppStyles.labelSmall)])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('ƯỚC TÍNH', style: AppStyles.labelSmall.copyWith(fontSize: 10)), Text(cashback, style: AppStyles.h1.copyWith(color: AppColors.accent, fontSize: 18))]),
      ]),
    );
  }

  Widget _buildRealResultCard(String rank, CreditCard card, String matchedLabels, String cashback) {
    final List<String> tags = matchedLabels.split(', ').where((s) => s.trim().isNotEmpty).take(2).toList();
    return AnimatedHover(
      scale: 1.03,
      child: InkWell(
        onTap: () => context.go('/card/${card.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5)),
          child: Row(children: [
            Text(rank, style: AppStyles.h1.copyWith(color: AppColors.primary.withValues(alpha: 0.2), fontSize: 24)),
            const SizedBox(width: 15),
            Container(width: 80, height: 50, decoration: BoxDecoration(color: const Color(0xFFF7F3EE), borderRadius: BorderRadius.circular(8)), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: card.imagePath.isNotEmpty ? Image.network(card.imagePath, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.credit_card)) : const Icon(Icons.credit_card))),
            const SizedBox(width: 15),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(card.name, style: AppStyles.h2.copyWith(fontSize: 15), maxLines: 1), Text(card.bankName, style: AppStyles.labelSmall.copyWith(color: AppColors.accentOrange, fontSize: 11)), if (tags.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 5), child: Wrap(spacing: 5, children: tags.map((l) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Text(l, style: const TextStyle(color: AppColors.success, fontSize: 9, fontWeight: FontWeight.bold)))).toList()))])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('HOÀN TIỀN', style: AppStyles.labelSmall.copyWith(fontSize: 10)), Text(cashback, style: AppStyles.h1.copyWith(color: AppColors.accentOrange, fontSize: 18))]),
          ]),
        ),
      ),
    );
  }
}
