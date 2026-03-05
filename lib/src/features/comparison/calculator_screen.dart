import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../constants/app_styles.dart';
import '../../common_widgets/animated_hover.dart';

class CalculatorScreen extends StatelessWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Header Navigation
            _buildHeader(context),

            // 2. Banner
            _buildBanner(screenWidth),

            // 3. Main Content
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1200),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                child: Column(
                  children: [
                    // Title
                    Text(
                      'TÍNH TOÁN',
                      textAlign: TextAlign.center,
                      style: AppStyles.h1.copyWith(
                        color: const Color(0xFFB4936A),
                        fontSize: isMobile ? 32 : 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Nhập chi tiết chi tiêu để tìm "chiến thần" hoàn tiền chính xác nhất.',
                      textAlign: TextAlign.center,
                      style: AppStyles.h2.copyWith(
                        color: const Color(0xFFB4936A),
                        fontSize: isMobile ? 18 : 22,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 50),

                    // Responsive Layout
                    if (isMobile)
                      Column(
                        children: [
                          _buildInputForm(isMobile),
                          const SizedBox(height: 40),
                          _buildTop5Cards(),
                        ],
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cột Trái: Form nhập liệu (Chiếm 6 phần)
                          Expanded(
                            flex: 6,
                            child: _buildInputForm(isMobile),
                          ),
                          const SizedBox(width: 40),
                          // Cột Phải: Top 5 Thẻ đề xuất (Chiếm 4 phần)
                          Expanded(
                            flex: 4,
                            child: _buildTop5Cards(),
                          ),
                        ],
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
      height: 80, // Kích thước chuẩn tinh tế
      padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          // Logo
          InkWell(
            onTap: () => context.go('/'),
            child: Image.asset(
              'assets/logo/logo.png',
              height: 45, // Chiều cao logo chuẩn
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Text(
                'baothe.vn',
                style: AppStyles.h1.copyWith(color: AppColors.accent, fontSize: 32),
              ),
            ),
          ),
          const Spacer(),
          // Menu Items
          _buildMenuItem('TRA CỨU', onTap: () => context.go('/')),
          _buildMenuItem('TÍNH TOÁN', isSelected: true),
        ],
      ),
    );
  }

  Widget _buildMenuItem(String title, {bool isSelected = false, VoidCallback? onTap}) {
    return AnimatedHover(
      scale: 1.02,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            title,
            style: AppStyles.h2.copyWith(
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? Colors.black : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBanner(double width) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 20),
        width: 1000,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: const LinearGradient(
            colors: [Color(0xFFFB923C), Color(0xFFFACC15)],
          ),
        ),
        child: const Center(
          child: Text(
            'BANNER SHB FINANCE',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildInputForm(bool isMobile) {
    final categories = [
      {'icon': Icons.mic, 'label': 'GIẢI TRÍ'},
      {'icon': Icons.fitness_center, 'label': 'FITNESS'},
      {'icon': Icons.spa, 'label': 'SPA/LÀM ĐẸP'},
      {'icon': Icons.shopping_bag, 'label': 'MUA SẮM'},
      {'icon': Icons.flight, 'label': 'DU LỊCH'},
      {'icon': Icons.directions_car, 'label': 'GRAB'},
      {'icon': Icons.eco, 'label': 'XANH SM'},
      {'icon': Icons.shopping_cart, 'label': 'TIKI'},
      {'icon': Icons.music_note, 'label': 'TIKTOK SHOP'},
      {'icon': Icons.favorite, 'label': 'SHOPEE'},
      {'icon': Icons.card_giftcard, 'label': 'LAZADA'},
      {'icon': Icons.fastfood, 'label': 'ĂN UỐNG'},
      {'icon': Icons.local_pizza, 'label': 'SHOPEEFOOD'},
      {'icon': Icons.local_grocery_store, 'label': 'SIÊU THỊ'},
      {'icon': Icons.school, 'label': 'GIÁO DỤC'},
      {'icon': Icons.local_hospital, 'label': 'Y TẾ'},
      {'icon': Icons.shield, 'label': 'BẢO HIỂM'},
      {'icon': Icons.motorcycle, 'label': 'BE'},
      {'icon': Icons.bed, 'label': 'PHÒNG CHỜ'},
      {'icon': Icons.more_horiz, 'label': 'KHÁC'},
    ];

    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFFDF6E3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.calculate, color: Color(0xFFB4936A), size: 30),
              ),
              const SizedBox(width: 15),
              Text(
                'Chi tiêu tháng này (VNĐ)',
                style: AppStyles.h1.copyWith(fontSize: 24, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 30),
          
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.5,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              return _buildInputField(
                categories[index]['icon'] as IconData,
                categories[index]['label'] as String,
                index == 0 ? '1.000.000' : '0',
              );
            },
          ),
          
          const SizedBox(height: 40),
          
          AnimatedHover(
            scale: 1.02,
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentOrange,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  'PHÂN TÍCH & TÌM THẺ',
                  style: AppStyles.buttonText.copyWith(fontSize: 18, letterSpacing: 1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(IconData icon, String label, String initialValue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label, 
                style: AppStyles.labelSmall.copyWith(fontSize: 12, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Expanded(
          child: TextField(
            controller: TextEditingController(text: initialValue),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.accentOrange, width: 1.5),
              ),
            ),
            style: AppStyles.bodyMedium.copyWith(fontSize: 14),
            keyboardType: TextInputType.number,
          ),
        ),
      ],
    );
  }

  Widget _buildTop5Cards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Top 5 thẻ đề xuất', style: AppStyles.h2.copyWith(fontSize: 20)),
                Text('Sắp xếp theo số tiền hoàn lại ước tính', style: AppStyles.labelSmall),
              ],
            ),
            TextButton(
              onPressed: () {},
              child: const Text('Xem tất cả thẻ', style: TextStyle(color: AppColors.accentOrange)),
            )
          ],
        ),
        const SizedBox(height: 20),
        
        _buildResultCard('#1', 'VCB Vibe...', '20% Du lịch/Khách sạn/Ăn uống max 300k', '200.000đ', Colors.orange),
        const SizedBox(height: 15),
        _buildResultCard('#2', 'VCB Cash...', '20% Mua sắm/Di chuyển/Online max 200k', '200.000đ', Colors.blue),
        const SizedBox(height: 15),
        _buildResultCard('#3', 'VCB Mas...', '15% Du lịch/Online/Mua sắm', '180.000đ', Colors.indigo),
        const SizedBox(height: 15),
        _buildResultCard('#4', 'VCB Visa...', '6-15% Du lịch/Online/Mua sắm (max 1.5tr)', '150.000đ', Colors.purple),
        const SizedBox(height: 15),
        _buildResultCard('#5', 'VCB Vietn...', '10% Mua sắm/Di chuyển (300k)|6.7%(1tr)', '200.000đ', Colors.green),
      ],
    );
  }

  Widget _buildResultCard(String rank, String cardName, String desc, String cashback, Color cardColor) {
    return AnimatedHover(
      scale: 1.03,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.8), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rank,
                  style: AppStyles.h1.copyWith(color: const Color(0xFFD1D5DB), fontSize: 24),
                ),
                const SizedBox(width: 15),
                Container(
                  width: 50,
                  height: 30,
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cardName, style: AppStyles.h2.copyWith(fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(desc, style: AppStyles.labelSmall.copyWith(fontSize: 12)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.check, color: AppColors.success, size: 16),
                          const SizedBox(width: 4),
                          Text('GIẢI TRÍ', style: AppStyles.labelSmall.copyWith(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 11)),
                        ],
                      )
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('HOÀN TIỀN\nTHÁNG', textAlign: TextAlign.right, style: AppStyles.labelSmall.copyWith(fontSize: 10)),
                    Text(cashback, style: AppStyles.h1.copyWith(color: AppColors.accentOrange, fontSize: 18)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 15),
            const Divider(color: AppColors.border),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Checkbox(
                  value: false,
                  onChanged: (v) {},
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                Text('Thêm vào so sánh', style: AppStyles.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
