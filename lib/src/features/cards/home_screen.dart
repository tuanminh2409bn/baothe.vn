import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../constants/app_styles.dart';
import '../../common_widgets/app_search_bar.dart';
import '../../common_widgets/animated_hover.dart';
import '../../models/credit_card_model.dart';

import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../comparison/comparison_provider.dart';
import '../favorites/favorites_provider.dart';

// Quản lý trạng thái tìm kiếm
final selectedBankProvider = StateProvider<String?>((ref) => null);
final selectedCategoryProvider = StateProvider<String?>((ref) => null);
final searchQueryProvider = StateProvider<String>((ref) => '');
final displayLimitProvider = StateProvider<int>((ref) => 6);
final selectedTierProvider = StateProvider<String?>((ref) => null);
final selectedTypeProvider = StateProvider<String?>((ref) => null);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final List<String> allCategoryLabels = [
    'ĐÃ LƯU', 'TẤT CẢ', 'GIẢI TRÍ', 'FITNESS', 'SPA/LÀM ĐẸP',
    'MUA SẮM', 'DU LỊCH', 'GRAB', 'XANH SM', 'TIKI',
    'TIKTOK SHOP', 'SHOPEE', 'LAZADA', 'ĂN UỐNG', 'SHOPEEFOOD',
    'SIÊU THỊ', 'GIÁO DỤC', 'Y TẾ', 'BẢO HIỂM', 'BE', 'PHÒNG CHỜ'
  ];
  
  late List<String> suggestedCategories;
  final TextEditingController _searchController = TextEditingController();

  // BIẾN CHO SLIDER
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final random = Random();
    suggestedCategories = (List<String>.from(allCategoryLabels)..shuffle(random)).take(5).toList();
    
    _pageController = PageController(initialPage: 0);
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_currentPage < 3) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final selectedBank = ref.watch(selectedBankProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final selectedTier = ref.watch(selectedTierProvider);
    final selectedType = ref.watch(selectedTypeProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final displayLimit = ref.watch(displayLimitProvider);
    
    final cardsAsync = ref.watch(cardsStreamProvider);
    final comparisonCards = ref.watch(comparisonProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: comparisonCards.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/compare'),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.compare_arrows, color: Colors.white),
              label: Text(
                'So sánh (${comparisonCards.length})',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context, ref),
            
            _buildBannerSlider(screenWidth),

            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1400),
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    const SizedBox(height: 45), 
                    
                    // TIÊU ĐỀ
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF4A3728), Color(0xFF8B5E34), Color(0xFF4A3728)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          'CÔNG CỤ TRA CỨU THẺ TÍN DỤNG\nTHÔNG MINH DÀNH CHO CHỦ TỊCH',
                          textAlign: TextAlign.center,
                          style: AppStyles.h1.copyWith(
                            color: Colors.white,
                            fontSize: screenWidth < 600 ? 28 : 46,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 50),
                    
                    // THANH TÌM KIẾM
                    Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: Column(
                          children: [
                            AppSearchBar(
                              controller: _searchController,
                              onSearch: (value) {
                                ref.read(selectedCategoryProvider.notifier).state = null; // Xóa danh mục khi gõ tìm kiếm
                                ref.read(selectedBankProvider.notifier).state = null; // Xóa ngân hàng khi gõ tìm kiếm mới
                                ref.read(searchQueryProvider.notifier).state = value;
                              },
                              onSearchPressed: () {},
                            ),
                            const SizedBox(height: 20),
                            _buildAdvancedFilterChips(ref),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    _buildSuggestedCategories(),
                    
                    const SizedBox(height: 80),

                    // KHU VỰC KẾT QUẢ A: TÌM KIẾM HOẶC CHỌN NGÂN HÀNG/HẠNG THẺ/LOẠI THẺ
                    if (searchQuery.isNotEmpty || selectedBank != null || selectedTier != null || selectedType != null)
                      _buildResultsSection(
                        cardsAsync, 
                        _getResultsTitle(selectedBank, selectedTier, selectedType, searchQuery), 
                        selectedBank, 
                        searchQuery, 
                        selectedTier,
                        selectedType,
                        displayLimit,
                        onClear: () {
                          ref.read(selectedBankProvider.notifier).state = null;
                          ref.read(selectedTierProvider.notifier).state = null;
                          ref.read(selectedTypeProvider.notifier).state = null;
                          ref.read(searchQueryProvider.notifier).state = '';
                          _searchController.clear();
                        }
                      ),
                  ],
                ),
              ),
            ),
            
            // Banks Section
            cardsAsync.when(
              data: (cards) {
                final availableBanks = cards.map((c) => c.bankName.trim().toLowerCase()).toSet();
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 40),
                  decoration: const BoxDecoration(color: Color(0xFFF7F3EE)),
                  child: _buildFullBanksSection(ref, selectedBank, availableBanks),
                );
              },
              loading: () => Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: const BoxDecoration(color: Color(0xFFF7F3EE)),
                child: const Center(child: CircularProgressIndicator(color: AppColors.accentOrange)),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
            
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1400),
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    _buildSecondaryBanner(),
                    const SizedBox(height: 60),

                    // KHU VỰC KẾT QUẢ B: CHỌN THEO DANH MỤC
                    if (selectedCategory != null)
                      _buildResultsSection(
                        cardsAsync, 
                        'Ưu đãi cho dịch vụ: $selectedCategory', 
                        null, 
                        selectedCategory, 
                        null, // tierFilter
                        null, // typeFilter
                        displayLimit,
                        onClear: () => ref.read(selectedCategoryProvider.notifier).state = null
                      ),

                    _buildCategoriesGrid(),
                    const SizedBox(height: 80),
                    _buildBottomBanner(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerSlider(double width) {
    double bannerWidth = width > 1480 ? 1400 : width - 80;
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 30),
        width: bannerWidth,
        // Sử dụng AspectRatio thay vì height cố định để đảm bảo ảnh không bị cắt
        child: AspectRatio(
          aspectRatio: 1400 / 500,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) => _currentPage = index,
                    children: [
                      _buildSliderItem('assets/web/slider1.png'),
                      _buildSliderItem('assets/web/slider2.png'),
                      _buildSliderItem('assets/web/slider3.png'),
                      _buildSliderItem('assets/web/slider4.png'),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 20, top: 0, bottom: 0,
                child: Center(child: _buildSliderButton(icon: Icons.arrow_back_ios_new, onTap: () => _pageController.previousPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOut))),
              ),
              Positioned(
                right: 20, top: 0, bottom: 0,
                child: Center(child: _buildSliderButton(icon: Icons.arrow_forward_ios, onTap: () => _pageController.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOut))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliderButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(30), child: Container(width: 45, height: 45, alignment: Alignment.center, child: Icon(icon, color: Colors.white, size: 18))),
    );
  }

  Widget _buildSliderItem(String assetPath) {
    return Image.asset(
      assetPath,
      fit: BoxFit.contain, // Đảm bảo hiện hết toàn bộ ảnh
      width: double.infinity,
    );
  }

  Widget _buildSecondaryBanner() {
    return Container(
      width: double.infinity, 
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AspectRatio(
          aspectRatio: 1400 / 300, 
          child: Image.asset(
            'assets/web/banner_mid.png',
            fit: BoxFit.contain, // Đổi sang contain để không bị cắt
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBanner() {
    return Container(
      width: double.infinity, 
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AspectRatio(
          aspectRatio: 1400 / 250, 
          child: Image.asset(
            'assets/web/banner_bottom.png',
            fit: BoxFit.contain, // Đổi sang contain để không bị cắt
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestedCategories() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Gợi ý cho bạn: ', style: AppStyles.labelSmall.copyWith(fontSize: 14)),
        const SizedBox(width: 8),
        ...suggestedCategories.map((cat) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: AnimatedHover(
            scale: 1.05,
            child: InkWell(
              onTap: () {
                ref.read(selectedCategoryProvider.notifier).state = cat;
                ref.read(selectedBankProvider.notifier).state = null;
                ref.read(searchQueryProvider.notifier).state = '';
                _searchController.clear();
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border.withValues(alpha: 0.5))),
                child: Text(cat, style: AppStyles.labelSmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateProvider);
    return Container(
      height: 80, padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5))),
      child: Row(
        children: [
          InkWell(onTap: () => context.go('/'), child: Image.asset('assets/logo/logo_web.png', height: 45, fit: BoxFit.contain)),
          const Spacer(),
          _buildMenuItem('TRA CỨU', isSelected: true),
          _buildMenuItem('TÍNH TOÁN', onTap: () => context.go('/calculator')),
          const SizedBox(width: 20),
          userAsync.when(
            data: (user) => user == null
                ? ElevatedButton(onPressed: () => context.go('/login'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Đăng nhập', style: TextStyle(color: Colors.white)))
                : Row(children: [Text(user.email ?? 'User', style: AppStyles.labelSmall), const SizedBox(width: 10), IconButton(icon: const Icon(Icons.logout, size: 20), onPressed: () => ref.read(authServiceProvider).signOut())]),
            loading: () => const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            error: (_, __) => const Icon(Icons.error),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(String title, {bool isSelected = false, VoidCallback? onTap}) {
    return AnimatedHover(
      scale: 1.02,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: Text(title, style: AppStyles.h2.copyWith(fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: isSelected ? AppColors.textPrimary : AppColors.textSecondary)))),
    );
  }

  Widget _buildFullBanksSection(WidgetRef ref, String? currentSelected, Set<String> availableBanks) {
    const double h1Height = 45;
    const double h1ContainerWidth = 110;
    const double commonHeight = 55;
    const double commonContainerWidth = 135;
    const double commonSpacing = 5;
    
    final paymentMethods = {'visa', 'mastercard', 'jcb', 'vietqr', 'napas', 'unionpay', 'samsung pay', 'apple pay', 'google pay', 'qr bank'};

    return Column(
      children: [
        _buildLogoRow(ref, [
          {'name': 'VietQR', 'file': 'vietqr.png'},
          {'name': 'Visa', 'file': 'visa.png'},
          {'name': 'Mastercard', 'file': 'mastercard.png'},
          {'name': 'JCB', 'file': 'jcb.png'},
          {'name': 'UnionPay', 'file': 'unionpay.png'},
          {'name': 'Napas', 'file': 'napas.png'},
          {'name': 'Samsung Pay', 'file': 'samsungpay.png'},
          {'name': 'Apple Pay', 'file': 'applepay.png'},
          {'name': 'Google Pay', 'file': 'googlepay.png'},
          {'name': 'QR Bank', 'file': 'qrbank.png'},
        ], availableBanks: availableBanks, alwaysActive: paymentMethods, height: h1Height, horizontalSpacing: commonSpacing, containerWidth: h1ContainerWidth, currentSelected: currentSelected),
        const SizedBox(height: 20),
        _buildLogoRow(ref, [
          {'name': 'VietinBank', 'file': 'vietinbank.png'},
          {'name': 'UOB', 'file': 'uob.png'},
          {'name': 'SeABank', 'file': 'seabank.png'},
          {'name': 'Kienlongbank', 'file': 'kienlongbank.png'},
          {'name': 'TPBank', 'file': 'tpbank.png'},
          {'name': 'Vietcombank', 'file': 'vietcombank.png'},
          {'name': 'MSB', 'file': 'msb.png'},
        ], availableBanks: availableBanks, height: commonHeight, horizontalSpacing: commonSpacing, containerWidth: commonContainerWidth, currentSelected: currentSelected),
        const SizedBox(height: 15),
        _buildLogoRow(ref, [
          {'name': 'VPBank', 'file': 'vpbank.png'},
          {'name': 'HSBC', 'file': 'hsbc.png'},
          {'name': 'VIB', 'file': 'vib.png'},
          {'name': 'BIDV', 'file': 'bidv.png'},
          {'name': 'MB', 'file': 'mb.png'},
          {'name': 'ACB', 'file': 'acb.png'},
          {'name': 'SHB', 'file': 'shb.png'},
        ], availableBanks: availableBanks, height: commonHeight, horizontalSpacing: commonSpacing, containerWidth: commonContainerWidth, currentSelected: currentSelected),
        const SizedBox(height: 15),
        _buildLogoRow(ref, [
          {'name': 'BVBank', 'file': 'bvbank.png'},
          {'name': 'Techcombank', 'file': 'techcombank.png'},
          {'name': 'SCB', 'file': 'scb.png'},
          {'name': 'OCB', 'file': 'ocb.png'},
          {'name': 'Standard Chartered', 'file': 'standardchartered.png'},
          {'name': 'Eximbank', 'file': 'eximbank.png'},
          {'name': 'Home Credit', 'file': 'homecredit.png'},
        ], availableBanks: availableBanks, height: commonHeight, horizontalSpacing: commonSpacing, containerWidth: commonContainerWidth, currentSelected: currentSelected),
        const SizedBox(height: 15),
        _buildLogoRow(ref, [
          {'name': 'PVcomBank', 'file': 'pvcombank.png'},
          {'name': 'LPBank', 'file': 'lpbank.png'},
          {'name': 'HDBank', 'file': 'hdbank.png'},
          {'name': 'Sacombank', 'file': 'sacombank.png'},
          {'name': 'MCredit', 'file': 'mcredit.png'},
          {'name': 'Lotte Finance', 'file': 'lottefinance.png'},
          {'name': 'Nam A Bank', 'file': 'nganhangnama.png'},
        ], availableBanks: availableBanks, height: commonHeight, horizontalSpacing: commonSpacing, containerWidth: commonContainerWidth, currentSelected: currentSelected),
        const SizedBox(height: 15),
        _buildLogoRow(ref, [
          {'name': 'Shinhan Bank', 'file': 'shinhanbank.png'},
          {'name': 'Shinhan Finance', 'file': 'shinhanfinance.png'},
          {'name': 'FE Credit', 'file': 'fecredit.png'},
          {'name': 'Woori Bank', 'file': 'wooribank.png'},
          {'name': 'VietBank', 'file': 'vietbank.png'},
        ], availableBanks: availableBanks, height: commonHeight, horizontalSpacing: commonSpacing, containerWidth: commonContainerWidth, currentSelected: currentSelected),
        const SizedBox(height: 15),
        _buildLogoRow(ref, [
          {'name': 'ShopeePay', 'file': 'shoppepay.png'},
          {'name': 'ViettelPay', 'file': 'viettelpay.png'},
          {'name': 'Momo', 'file': 'momo.png'},
          {'name': 'Vimo', 'file': 'vimo.png'},
        ], availableBanks: availableBanks, height: commonHeight, horizontalSpacing: commonSpacing, containerWidth: commonContainerWidth, currentSelected: currentSelected),
      ],
    );
  }

  Widget _buildLogoRow(WidgetRef ref, List<Map<String, String>> items, {
    required Set<String> availableBanks,
    Set<String>? alwaysActive,
    double height = 50, 
    double horizontalSpacing = 10, 
    double containerWidth = 140, 
    String? currentSelected
  }) {
    return Wrap(
      spacing: horizontalSpacing, runSpacing: 10, alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center,
      children: items.map((item) {
        final bankName = item['name']!.trim().toLowerCase();
        final bool isAvailable = (alwaysActive != null && alwaysActive.contains(bankName)) || availableBanks.contains(bankName);
        final isSelected = currentSelected == item['name'];
        
        return AnimatedHover(
          scale: 1.1, 
          child: InkWell(
            onTap: isAvailable ? () {
              ref.read(selectedCategoryProvider.notifier).state = null; // Xóa danh mục khi chọn ngân hàng
              ref.read(searchQueryProvider.notifier).state = ''; // Xóa tìm kiếm chữ
              ref.read(selectedBankProvider.notifier).state = item['name'];
            } : null, 
            borderRadius: BorderRadius.circular(8), 
            child: Container(
              width: containerWidth, 
              height: height + 15, 
              alignment: Alignment.center, 
              decoration: BoxDecoration(
                color: Colors.transparent, 
                border: Border.all(color: isSelected ? AppColors.accentOrange : Colors.transparent, width: 1.5), 
                borderRadius: BorderRadius.circular(8)
              ), 
              child: Image.asset(
                'assets/logo/${item['file']}', 
                height: height, 
                fit: BoxFit.contain, 
                errorBuilder: (context, error, stackTrace) => Text(item['name']!, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center)
              )
            ),
          )
        );
      }).toList(),
    );
  }

  Widget _buildCreditCardGrid(List<CreditCard> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 3;
        if (constraints.maxWidth < 700) {
          crossAxisCount = 1;
        } else if (constraints.maxWidth < 1100) {
          crossAxisCount = 2;
        }
        return GridView.builder(shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 20), physics: const NeverScrollableScrollPhysics(), gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: crossAxisCount, childAspectRatio: 0.82, crossAxisSpacing: 30, mainAxisSpacing: 30), itemCount: cards.length, itemBuilder: (context, index) => _buildCreditCardItem(cards[index]));
      },
    );
  }

  Widget _buildCreditCardItem(CreditCard card) {
    final favorites = ref.watch(favoritesProvider);
    final isFavorite = favorites.contains(card.id);

    return AnimatedHover(
      scale: 1.03,
      child: InkWell(
        onTap: () => context.go('/card/${card.id}'),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 15,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Section
              Expanded(
                flex: 40,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF7F3EE),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Hero(
                          tag: card.id,
                          child: card.imagePath.startsWith('http')
                              ? Image.network(
                                  card.imagePath,
                                  fit: BoxFit.contain,
                                  loadingBuilder: (context, child, loadingProgress) =>
                                      loadingProgress == null
                                          ? child
                                          : const Center(
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: AppColors.accentOrange)),
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.credit_card,
                                          color: AppColors.textLight, size: 60),
                                )
                              : Image.asset(
                                  card.imagePath,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.credit_card,
                                          color: AppColors.textLight, size: 60),
                                ),
                        ),
                      ),
                      Positioned(
                        top: -10,
                        right: -10,
                        child: IconButton(
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.red : AppColors.textLight,
                          ),
                          onPressed: () {
                            ref.read(favoritesProvider.notifier).toggleFavorite(card.id);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Content Section
              Expanded(
                flex: 60,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Scrollable content area
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                card.name,
                                style: AppStyles.h2.copyWith(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.accentOrange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  card.cashbackHighlight.toUpperCase(),
                                  style: AppStyles.labelSmall.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.accentOrange,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Display ALL details without maxLines restriction
                              ...card.details.map((detail) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.check_circle,
                                            size: 14, color: Color(0xFFB4936A)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            detail,
                                            style: AppStyles.bodyMedium.copyWith(
                                              fontSize: 13,
                                              color: Colors.black87,
                                              height: 1.3,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Action Buttons (Fixed at bottom)
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Mở thẻ ngay',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Material(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              onTap: () {
                                ref.read(comparisonProvider.notifier).addCard(card);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Đã thêm ${card.name} vào danh sách so sánh')),
                                );
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color:
                                          AppColors.border.withValues(alpha: 0.5)),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.compare_arrows,
                                    color: AppColors.primary, size: 20),
                              ),
                            ),
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
      ),
    );
  }

  Widget _buildCategoriesGrid() {
    final categories = [
      {'icon': FontAwesomeIcons.solidHeart, 'label': 'ĐÃ LƯU'}, 
      {'icon': FontAwesomeIcons.infinity, 'label': 'TẤT CẢ'}, 
      {'icon': FontAwesomeIcons.microphone, 'label': 'GIẢI TRÍ'}, 
      {'icon': FontAwesomeIcons.dumbbell, 'label': 'FITNESS'}, 
      {'icon': FontAwesomeIcons.spa, 'label': 'SPA/LÀM ĐẸP'}, 
      {'icon': FontAwesomeIcons.bagShopping, 'label': 'MUA SẮM'}, 
      {'icon': FontAwesomeIcons.plane, 'label': 'DU LỊCH'}, 
      {'icon': FontAwesomeIcons.car, 'label': 'GRAB'}, 
      {'icon': FontAwesomeIcons.bolt, 'label': 'XANH SM'}, 
      {'icon': FontAwesomeIcons.gem, 'label': 'TIKI'}, 
      {'icon': FontAwesomeIcons.tiktok, 'label': 'TIKTOK SHOP'}, 
      {'icon': FontAwesomeIcons.basketShopping, 'label': 'SHOPEE'}, 
      {'icon': FontAwesomeIcons.gift, 'label': 'LAZADA'}, 
      {'icon': FontAwesomeIcons.burger, 'label': 'ĂN UỐNG'}, 
      {'icon': FontAwesomeIcons.pizzaSlice, 'label': 'SHOPEEFOOD'}, 
      {'icon': FontAwesomeIcons.carrot, 'label': 'SIÊU THỊ'}, 
      {'icon': FontAwesomeIcons.graduationCap, 'label': 'GIÁO DỤC'}, 
      {'icon': FontAwesomeIcons.briefcaseMedical, 'label': 'Y TẾ'}, 
      {'icon': FontAwesomeIcons.shieldHalved, 'label': 'BẢO HIỂM'}, 
      {'icon': FontAwesomeIcons.bugs, 'label': 'BE'}, 
      {'icon': FontAwesomeIcons.bed, 'label': 'PHÒNG CHỜ'}
    ];

    return Column(
      children: [
        // Category Section Header
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 40, height: 1, color: const Color(0xFFD4AF37)),
            const SizedBox(width: 15),
            Text(
              'DANH MỤC ĐẶC QUYỀN',
              style: AppStyles.h2.copyWith(
                fontSize: 18,
                letterSpacing: 4,
                color: const Color(0xFF4A3728),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 15),
            Container(width: 40, height: 1, color: const Color(0xFFD4AF37)),
          ],
        ),
        const SizedBox(height: 40),
        
        LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = 7; // Tăng lên 7 để trông thanh thoát hơn trên web
            if (constraints.maxWidth < 600) {
              crossAxisCount = 2;
            } else if (constraints.maxWidth < 1000) {
              crossAxisCount = 4;
            }
            
            return GridView.builder(
              shrinkWrap: true, 
              physics: const NeverScrollableScrollPhysics(), 
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount, 
                childAspectRatio: 0.95, // Gần vuông
                crossAxisSpacing: 20, 
                mainAxisSpacing: 20
              ), 
              itemCount: categories.length, 
              itemBuilder: (context, index) => _buildCategoryItem(
                categories[index]['icon'] as IconData, 
                categories[index]['label'] as String
              )
            );
          }
        ),
      ],
    );
  }

  Widget _buildCategoryItem(IconData icon, String label) {
    final isSelected = ref.watch(selectedCategoryProvider) == label;
    
    return AnimatedHover(
      scale: 1.08, 
      useOrangeGlow: true,
      child: InkWell(
        onTap: () {
          if (label == 'TẤT CẢ') {
            ref.read(selectedBankProvider.notifier).state = null;
            ref.read(selectedCategoryProvider.notifier).state = null;
            ref.read(searchQueryProvider.notifier).state = '';
            _searchController.clear();
          } else if (label == 'ĐÃ LƯU') {
            ref.read(selectedBankProvider.notifier).state = null;
            ref.read(searchQueryProvider.notifier).state = '';
            _searchController.clear();
            ref.read(selectedCategoryProvider.notifier).state = label;
          } else {
            ref.read(selectedBankProvider.notifier).state = null;
            ref.read(searchQueryProvider.notifier).state = '';
            _searchController.clear();
            ref.read(selectedCategoryProvider.notifier).state = label;
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4A3728) : Colors.white, 
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFF4A3728).withValues(alpha: 0.1), 
              width: 1.5
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isSelected ? 0.1 : 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ), 
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, 
            children: [
              // Icon Container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFF7F3EE),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                    width: 1,
                  )
                ),
                child: FaIcon(
                  icon, 
                  size: 24, 
                  color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFF8B5E34)
                ),
              ),
              const SizedBox(height: 15), 
              Text(
                label, 
                textAlign: TextAlign.center,
                style: AppStyles.labelSmall.copyWith(
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold, 
                  color: isSelected ? Colors.white : const Color(0xFF4A3728), 
                  fontSize: 11,
                  letterSpacing: 1.2,
                )
              )
            ]
          )
        ),
      )
    );
  }

  String _getResultsTitle(String? bank, String? tier, String? type, String search) {
    List<String> parts = [];
    if (bank != null) parts.add('Ngân hàng: $bank');
    if (tier != null) parts.add('Hạng: $tier');
    if (type != null) parts.add('Loại: $type');
    if (search.isNotEmpty) parts.add('Tìm kiếm: "$search"');
    
    if (parts.isEmpty) return 'Tất cả thẻ';
    return 'Kết quả cho: ${parts.join(' | ')}';
  }

  Widget _buildAdvancedFilterChips(WidgetRef ref) {
    final selectedTier = ref.watch(selectedTierProvider);
    final selectedType = ref.watch(selectedTypeProvider);
    
    final tiers = ['Platinum', 'Signature', 'Infinite', 'Gold', 'Classic'];
    final types = ['Visa', 'Mastercard', 'JCB', 'Napas'];

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Hạng thẻ: ', style: AppStyles.labelSmall.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              ...tiers.map((tier) => _buildFilterChip(
                tier, 
                selectedTier == tier, 
                () {
                  final notifier = ref.read(selectedTierProvider.notifier);
                  notifier.state = (notifier.state == tier) ? null : tier;
                  if (notifier.state != null) {
                    ref.read(selectedCategoryProvider.notifier).state = null;
                  }
                }
              )),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Loại thẻ: ', style: AppStyles.labelSmall.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              ...types.map((type) => _buildFilterChip(
                type, 
                selectedType == type, 
                () {
                  final notifier = ref.read(selectedTypeProvider.notifier);
                  notifier.state = (notifier.state == type) ? null : type;
                  if (notifier.state != null) {
                    ref.read(selectedCategoryProvider.notifier).state = null;
                  }
                }
              )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary.withValues(alpha: 0.2),
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
        ),
      ),
    );
  }

  Widget _buildResultsSection(AsyncValue<List<CreditCard>> cardsAsync, String title, String? bankFilter, String? queryFilter, String? tierFilter, String? typeFilter, int limit, {required VoidCallback onClear}) {
    final favorites = ref.watch(favoritesProvider);
    
    return cardsAsync.when(
      data: (cards) {
        final List<CreditCard> filteredCards = cards.where((card) {
          // Xử lý danh mục "ĐÃ LƯU"
          if (queryFilter == 'ĐÃ LƯU') {
            return favorites.contains(card.id);
          }

          final String q = (queryFilter ?? '').toLowerCase();
          final String b = (bankFilter ?? '').toLowerCase();
          final String t = (tierFilter ?? '').toLowerCase();
          final String tp = (typeFilter ?? '').toLowerCase();
          
          bool matchesBank = true;
          if (b.isNotEmpty) {
            final cardTypes = {'visa', 'mastercard', 'jcb', 'vietqr', 'napas', 'unionpay', 'samsung pay', 'apple pay', 'google pay', 'qr bank'};
            if (cardTypes.contains(b)) {
              matchesBank = card.name.toLowerCase().contains(b) || (card.cardType?.toLowerCase().contains(b) ?? false);
            } else {
              matchesBank = card.bankName.toLowerCase().contains(b);
            }
          }

          bool matchesTier = true;
          if (t.isNotEmpty) {
            matchesTier = card.cardTier?.toLowerCase().contains(t) ?? false || 
                          card.name.toLowerCase().contains(t);
          }

          bool matchesType = true;
          if (tp.isNotEmpty) {
            matchesType = card.cardType?.toLowerCase().contains(tp) ?? false || 
                          card.name.toLowerCase().contains(tp);
          }
          
          bool matchesSearch = true;
          if (q.isNotEmpty) {
            matchesSearch = card.name.toLowerCase().contains(q) || 
                card.bankName.toLowerCase().contains(q) ||
                card.cashbackHighlight.toLowerCase().contains(q);
            
            if (!matchesSearch) {
              matchesSearch = card.details.any((d) => d.toLowerCase().contains(q));
            }

            if (!matchesSearch && card.benefitsDetail != null) {
              matchesSearch = card.benefitsDetail!.any((benefit) => 
                  (benefit['title']?.toLowerCase().contains(q) ?? false) || 
                  (benefit['content']?.toLowerCase().contains(q) ?? false));
            }
          }

          return matchesBank && matchesTier && matchesType && matchesSearch;
        }).toList();

        if (filteredCards.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('Không tìm thấy thẻ phù hợp.', style: TextStyle(color: AppColors.textSecondary, fontSize: 16))),
          );
        }

        final displayCards = filteredCards.take(limit).toList();
        final bool hasMore = filteredCards.length > limit;

        return Column(
          children: [
            Row(
              children: [
                Text(title, style: AppStyles.bodyMedium.copyWith(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.accentOrange, borderRadius: BorderRadius.circular(12)),
                  child: Text('${filteredCards.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onClear,
                  child: const Text('Đóng kết quả', style: TextStyle(color: Colors.red, fontSize: 16)),
                ),
              ],
            ),
            const SizedBox(height: 30),
            _buildCreditCardGrid(displayCards),
            if (filteredCards.length > 6)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: OutlinedButton(
                    onPressed: () {
                      if (hasMore) {
                        ref.read(displayLimitProvider.notifier).state += 6;
                      } else {
                        ref.read(displayLimitProvider.notifier).state = 6;
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(hasMore ? 'XEM THÊM' : 'THU GỌN', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        const SizedBox(width: 10),
                        Icon(hasMore ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 40),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accentOrange)),
      error: (err, stack) => Center(child: Text('Lỗi: $err', style: const TextStyle(color: Colors.red))),
    );
  }
}
