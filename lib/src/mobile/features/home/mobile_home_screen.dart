import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../constants/app_styles.dart';
import '../../../models/credit_card_model.dart';
import '../../../models/transaction_model.dart';
import '../../../models/user_card_model.dart';
import '../../../models/user_wallet_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';

class MobileHomeScreen extends ConsumerStatefulWidget {
  const MobileHomeScreen({super.key});

  @override
  ConsumerState<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends ConsumerState<MobileHomeScreen> {
  final PageController _cardController = PageController(viewportFraction: 0.85);

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authServiceProvider).currentUser;
    final userCardsAsync = user != null
        ? ref.watch(userCardsStreamProvider(user.uid))
        : const AsyncValue<List<UserCard>>.data([]);

    final transactionsAsync = user != null
        ? ref.watch(transactionsStreamProvider(user.uid))
        : const AsyncValue<List<Transaction>>.data([]);

    final userWalletsAsync = user != null
        ? ref.watch(userWalletsStreamProvider(user.uid))
        : const AsyncValue<List<UserWallet>>.data([]);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _buildCreditCardSlider(userCardsAsync),
            const SizedBox(height: 24),
            _buildWalletsSummary(userCardsAsync, userWalletsAsync),
            const SizedBox(height: 30),
            _buildCategories(context),
            const SizedBox(height: 30),
            _buildQuickActions(userCardsAsync),
            const SizedBox(height: 30),
            _buildRecentTransactions(transactionsAsync, userCardsAsync),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final authUser = ref.watch(authServiceProvider).currentUser;
    final userProfileAsync = authUser != null 
        ? ref.watch(userProfileProvider(authUser.uid))
        : const AsyncValue<Map<String, dynamic>?>.data(null);

    // Xác định lời chào dựa trên thời gian
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Chào buổi sáng,';
    } else if (hour < 18) {
      greeting = 'Chào buổi chiều,';
    } else {
      greeting = 'Chào buổi tối,';
    }

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: userProfileAsync.when(
        data: (profile) {
          final displayName = profile?['displayName'] ?? authUser?.displayName ?? authUser?.email?.split('@')[0] ?? 'Người dùng';
          final photoURL = profile?['photoURL'] ?? authUser?.photoURL;
          
          return Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary(context),
                backgroundImage: photoURL != null ? NetworkImage(photoURL) : null,
                child: photoURL == null ? Text(
                  displayName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ) : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  Text(
                    displayName,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const Text('Lỗi tải profile'),
      ),
      actions: [
        IconButton(
          icon: const Badge(child: Icon(Icons.notifications_none_rounded)),
          onPressed: () {},
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildWalletsSummary(
    AsyncValue<List<UserCard>> cardsAsync,
    AsyncValue<List<UserWallet>> walletsAsync,
  ) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Dư nợ thẻ tín dụng
          Expanded(
            child: GestureDetector(
              onTap: () => context.push('/wallet'),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border(context).withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.credit_card_rounded, size: 20, color: Colors.red.shade600),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Dư nợ tín dụng',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    cardsAsync.when(
                      data: (cards) {
                        final isMock = cards.isEmpty;
                        final total = isMock ? 45200000.0 : cards.fold<double>(0, (sum, item) => sum + item.balance);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currencyFormat.format(total),
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (isMock)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'DEMO',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                      loading: () => const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      error: (_, _) => const Text('Lỗi tải'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Ví chi tiêu cá nhân
          Expanded(
            child: GestureDetector(
              onTap: () => context.push('/wallet', extra: 1),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border(context).withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.account_balance_wallet_rounded, size: 20, color: Colors.green.shade600),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ví cá nhân',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    walletsAsync.when(
                      data: (wallets) {
                        final isMock = wallets.isEmpty;
                        final total = isMock ? 15500000.0 : wallets.fold<double>(0, (sum, item) => sum + item.balance);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currencyFormat.format(total),
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (isMock)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'DEMO',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                      loading: () => const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      error: (_, _) => const Text('Lỗi tải'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1);
  }

  Widget _buildCreditCardSlider(
    AsyncValue<List<UserCard>> cardsAsync,
  ) {
    final mockCards = ref.watch(mockCardsProvider);
    
    return cardsAsync.when(
      data: (cards) {
        final isEmpty = cards.isEmpty;
        final itemCount = isEmpty ? (mockCards.isEmpty ? 3 : mockCards.length) : cards.length;
        
        return Column(
          children: [
            SizedBox(
              height: 220, // Giảm chiều cao slider
              child: PageView.builder(
                controller: _cardController,
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  if (isEmpty) {
                    final mockCard = mockCards.length > index ? mockCards[index] : null;
                    return _buildMockCreditCardItem(mockCard, index);
                  }
                  return _buildCreditCardItem(cards[index], index);
                },
              ),
            ),
            const SizedBox(height: 16),
            SmoothPageIndicator(
              controller: _cardController,
              count: itemCount,
              effect: ExpandingDotsEffect(
                dotHeight: 6,
                dotWidth: 6,
                activeDotColor: AppColors.primary(context),
                dotColor: AppColors.border(context),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Text('Lỗi tải thẻ'),
    );
  }

  Widget _buildMockCreditCardItem(CreditCard? card, int index) {
    return Column(
      children: [
        Container(
          height: 160,
          margin: const EdgeInsets.only(right: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: index % 2 == 0 
                ? [const Color(0xFF1E293B), const Color(0xFF334155)]
                : [const Color(0xFF4338CA), const Color(0xFF6366F1)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(Icons.contactless_outlined, color: Colors.white54),
                    Icon(Icons.credit_card, color: Colors.white54),
                  ],
                ),
                const Spacer(),
                Text(
                  card?.name ?? 'Thẻ mẫu',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  card?.bankName ?? 'Ngân hàng',
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreditCardItem(UserCard card, int index) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 160,
          margin: const EdgeInsets.only(right: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Color(0xFF1E293B),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Ảnh thẻ...
                Positioned.fill(
                  child: card.imagePath.isNotEmpty
                      ? (card.imagePath.startsWith('http')
                          ? Image.network(
                              card.imagePath,
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              errorBuilder: (_, _, _) => _buildFallbackGradient(index),
                            )
                          : Image.asset(
                              card.imagePath,
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              errorBuilder: (_, _, _) => _buildFallbackGradient(index),
                            ))
                      : _buildFallbackGradient(index),
                ),
                // Overlay...
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.1),
                          Colors.black.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                  ),
                ),
                // Nội dung thông tin trên thẻ
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(Icons.contactless_outlined, color: Colors.white70),
                          Text(
                            'CREDIT CARD',
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 10,
                              letterSpacing: 2,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        card.cardName,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          shadows: [const Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        card.bankName,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(right: 15),
          child: _buildCashbackBadges(card),
        ),
      ],
    ).animate().scale(delay: (index * 50).ms, duration: 400.ms, curve: Curves.easeOutBack);
  }

  Widget _buildCashbackBadges(UserCard card) {
    final List<Widget> badges = [];
    
    // 1. Luôn hiển thị hoàn tiền chi tiêu chung nếu có
    if ((card.otherCashbackRate ?? 0) > 0) {
      badges.add(_buildSingleBadge('Chi tiêu: ${card.otherCashbackRate?.toStringAsFixed(0)}%', Colors.green.shade600));
    }

    // 2. Tìm top các hạng mục hoàn tiền khác
    final cashbackRates = {
      'Siêu thị': card.supermarketCashbackRate ?? 0,
      'Online': card.onlineCashbackRate ?? 0,
      'Du lịch': card.travelCashbackRate ?? 0,
      'Ẩm thực': card.diningCashbackRate ?? 0,
      'Y tế': card.medicalCashbackRate ?? 0,
      'Giáo dục': card.educationCashbackRate ?? 0,
      'Di chuyển': card.transportCashbackRate ?? 0,
      'Mua sắm': card.shoppingCashbackRate ?? 0,
      'Bảo hiểm': card.insuranceCashbackRate ?? 0,
      'Hóa đơn': card.utilitiesCashbackRate ?? 0,
      'Giải trí': card.entertainmentCashbackRate ?? 0,
      'Gym': card.gymCashbackRate ?? 0,
    };

    final sortedEntries = cashbackRates.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    int count = 0;
    for (var entry in sortedEntries) {
      if (entry.value > 0 && count < 3) { // Lấy thêm 3 hạng mục cao nhất để đầy hàng ngang
        badges.add(_buildSingleBadge('${entry.key}: ${entry.value.toStringAsFixed(0)}%', AppColors.primary(context)));
        count++;
      }
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.start,
      children: badges,
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildSingleBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flash_on_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackGradient(int index) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: index % 2 == 0
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF312E81), const Color(0xFF4338CA)],
        ),
      ),
    );
  }

  Widget _buildCategories(BuildContext context) {
    final allCategories = [
      {
        'icon': Icons.shopping_bag_rounded,
        'label': 'Mua sắm',
        'color': Colors.pink.shade50,
        'iconColor': Colors.pink,
        'keywords': [
          'mua sắm',
          'shopping',
          'siêu thị',
          'shopee',
          'tiki',
          'lazada',
        ],
      },
      {
        'icon': Icons.local_hospital_rounded,
        'label': 'Y tế',
        'color': Colors.blue.shade50,
        'iconColor': Colors.blue,
        'keywords': ['y tế', 'bệnh viện', 'sức khỏe', 'pharmacy', 'thuốc'],
      },
      {
        'icon': Icons.fitness_center_rounded,
        'label': 'Gym',
        'color': Colors.teal.shade50,
        'iconColor': Colors.teal,
        'keywords': ['gym', 'fitness', 'thể thao', 'tập luyện'],
      },
      {
        'icon': Icons.school_rounded,
        'label': 'Giáo dục',
        'color': Colors.amber.shade50,
        'iconColor': Colors.amber.shade700,
        'keywords': ['giáo dục', 'học phí', 'trường học', 'school'],
      },
      {
        'icon': Icons.local_grocery_store_rounded,
        'label': 'Siêu thị',
        'color': Colors.indigo.shade50,
        'iconColor': Colors.indigo,
        'keywords': ['siêu thị', 'lotte mart', 'winmart', 'coop mart'],
      },
      {
        'icon': Icons.flight_takeoff_rounded,
        'label': 'Du lịch',
        'color': Colors.cyan.shade50,
        'iconColor': Colors.cyan,
        'keywords': [
          'du lịch',
          'travel',
          'vé máy bay',
          'khách sạn',
          'hotel',
          'resort',
          'phòng chờ',
        ],
      },
      {
        'icon': Icons.fastfood_rounded,
        'label': 'Ăn uống',
        'color': Colors.orange.shade50,
        'iconColor': Colors.deepOrange,
        'keywords': ['ăn uống', 'ẩm thực', 'nhà hàng', 'dining'],
      },
      {
        'icon': Icons.mic_rounded,
        'label': 'Giải trí',
        'color': Colors.purple.shade50,
        'iconColor': Colors.purple,
        'keywords': ['giải trí', 'xem phim', 'cinema', 'netflix', 'spotify'],
      },
      {
        'icon': Icons.spa_rounded,
        'label': 'Spa/Làm đẹp',
        'color': Colors.pink.shade100,
        'iconColor': Colors.pink.shade700,
        'keywords': ['spa', 'làm đẹp', 'beauty', 'cosmetic', 'mỹ phẩm'],
      },
      {
        'icon': Icons.directions_car_rounded,
        'label': 'Grab',
        'color': Colors.green.shade50,
        'iconColor': Colors.green,
        'keywords': ['grab'],
      },
      {
        'icon': Icons.eco_rounded,
        'label': 'Xanh SM',
        'color': Colors.lightGreen.shade50,
        'iconColor': Colors.lightGreen,
        'keywords': ['xanh sm'],
      },
      {
        'icon': Icons.shopping_cart_rounded,
        'label': 'Tiki',
        'color': Colors.blue.shade100,
        'iconColor': Colors.blue.shade700,
        'keywords': ['tiki'],
      },
      {
        'icon': Icons.music_note_rounded,
        'label': 'Tiktok Shop',
        'color': Colors.grey.shade200,
        'iconColor': Colors.black,
        'keywords': ['tiktok shop'],
      },
      {
        'icon': Icons.favorite_rounded,
        'label': 'Shopee',
        'color': Colors.orange.shade100,
        'iconColor': Colors.orange.shade800,
        'keywords': ['shopee'],
      },
      {
        'icon': Icons.card_giftcard_rounded,
        'label': 'Lazada',
        'color': Colors.indigo.shade100,
        'iconColor': Colors.indigo.shade700,
        'keywords': ['lazada'],
      },
      {
        'icon': Icons.local_pizza_rounded,
        'label': 'ShopeeFood',
        'color': Colors.red.shade50,
        'iconColor': Colors.red,
        'keywords': ['shopeefood'],
      },
      {
        'icon': Icons.shield_rounded,
        'label': 'Bảo hiểm',
        'color': Colors.blueGrey.shade50,
        'iconColor': Colors.blueGrey,
        'keywords': ['bảo hiểm', 'insurance'],
      },
      {
        'icon': Icons.motorcycle_rounded,
        'label': 'Be',
        'color': Colors.yellow.shade100,
        'iconColor': Colors.yellow.shade800,
        'keywords': ['be'],
      },
      {
        'icon': Icons.bed_rounded,
        'label': 'Phòng chờ',
        'color': Colors.brown.shade50,
        'iconColor': Colors.brown,
        'keywords': ['phòng chờ', 'lounge'],
      },
      {
        'icon': Icons.more_horiz_rounded,
        'label': 'Chi tiêu',
        'color': Colors.grey.shade200,
        'iconColor': Colors.grey.shade700,
        'keywords': [],
      },
    ];

    final topCategories = allCategories.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Danh mục chi tiêu',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context),
                ),
              ),
              TextButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: AppColors.surface(context),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                    ),
                    builder: (context) => DraggableScrollableSheet(
                      expand: false,
                      initialChildSize: 0.7,
                      maxChildSize: 0.9,
                      builder: (context, scrollController) => Container(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: AppColors.border(context),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'TẤT CẢ DANH MỤC',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Expanded(
                              child: GridView.builder(
                                controller: scrollController,
                                physics: const BouncingScrollPhysics(),
                                itemCount: allCategories.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 4,
                                      mainAxisSpacing: 20,
                                      crossAxisSpacing: 10,
                                      childAspectRatio: 0.65,
                                    ),
                                itemBuilder: (context, index) {
                                  final cat = allCategories[index];
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.pop(context);
                                      _showCategoryCards(context, cat);
                                    },
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            color: cat['color'] as Color,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            cat['icon'] as IconData,
                                            color: cat['iconColor'] as Color,
                                            size: 28,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          cat['label'] as String,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textPrimary(context),
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                child: Text('Xem tất cả', style: TextStyle(color: AppColors.primary(context))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: topCategories.length,
            itemBuilder: (context, index) {
              final cat = topCategories[index];
              return GestureDetector(
                    onTap: () => _showCategoryCards(context, cat),
                    child: Container(
                      width: 72,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: cat['color'] as Color,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              cat['icon'] as IconData,
                              color: cat['iconColor'] as Color,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            cat['label'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary(context),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  )
                  .animate()
                  .fade(delay: (index * 50).ms)
                  .scale(delay: (index * 50).ms);
            },
          ),
        ),
      ],
    );
  }

  void _showCategoryCards(BuildContext context, Map<String, dynamic> category) {
    final cardsAsync = ref.read(cardsStreamProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border(context),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'THẺ HOÀN TIỀN CHO: ${category['label'].toString().toUpperCase()}',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: cardsAsync.when(
                      data: (allCards) {
                        final keywords = category['keywords'] as List<String>;
                        final matchedCards = allCards.where((card) {
                          final cashback = (card.cashbackHighlight)
                              .toLowerCase();
                          final benefitsStr = (card.benefits?.join(' ') ?? '')
                              .toLowerCase();
                          final detailsStr = (card.details.join(
                            ' ',
                          )).toLowerCase();
                          final combined = '$cashback $benefitsStr $detailsStr';
                          if (keywords.isEmpty && category['label'] == 'Chi tiêu') {
                            return true;
                          }
                          return keywords.any((kw) => combined.contains(kw));
                        }).toList();

                        if (matchedCards.isEmpty) {
                          return Center(
                            child: Text(
                              'Không tìm thấy thẻ phù hợp trong danh mục này.',
                              style: TextStyle(color: AppColors.textSecondary(context)),
                            ),
                          );
                        }

                        return ListView.separated(
                          controller: scrollController,
                          physics: const BouncingScrollPhysics(),
                          itemCount: matchedCards.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final card = matchedCards[index];
                            return _buildRecommendedCard(card);
                          },
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, stack) =>
                          const Center(child: Text('Lỗi tải dữ liệu thẻ')),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRecommendedCard(CreditCard card) {
    return GestureDetector(
      onTap: () {
        context.push('/public-card-detail', extra: card);
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border(context).withValues(alpha: 0.5)),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
          Container(
            width: 80,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: AppColors.background(context),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: card.imagePath.startsWith('http')
                  ? Image.network(
                      card.imagePath,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
                          Icon(Icons.credit_card, color: AppColors.textLight(context)),
                    )
                  : Image.asset(
                      card.imagePath,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
                          Icon(Icons.credit_card, color: AppColors.textLight(context)),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.name,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  card.bankName,
                  style: GoogleFonts.inter(
                    color: AppColors.textLight(context),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  card.cashbackHighlight,
                  style: GoogleFonts.inter(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildQuickActions(AsyncValue<List<UserCard>> cardsAsync) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tính năng',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.analytics_rounded,
                  label: 'Báo cáo',
                  color: Color(0xFFFAF5FF),
                  iconColor: Colors.purple,
                  onTap: () => context.push('/reports'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.compare_arrows_rounded,
                  label: 'So sánh thẻ',
                  color: Color(0xFFEFF6FF),
                  iconColor: Colors.blue,
                  onTap: () => context.push('/compare'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.calculate_outlined,
                  label: 'Công cụ\ntính toán',
                  color: Color(0xFFFFF7ED),
                  iconColor: Colors.orange,
                  onTap: () => context.push('/calculator'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.star_outline_rounded,
                  label: 'Thẻ\nyêu thích',
                  color: Color(0xFFF0FDF4),
                  iconColor: Colors.green,
                  onTap: () => context.push('/favorites'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(
    AsyncValue<List<Transaction>> txAsync,
    AsyncValue<List<UserCard>> cardsAsync,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Giao dịch gần đây',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context),
                ),
              ),
              TextButton(
                onPressed: () {}, 
                child: Text('Xem tất cả', style: TextStyle(color: AppColors.primary(context)))
              ),
            ],
          ),
          const SizedBox(height: 10),

          txAsync.when(
            data: (txs) {
              final cardsData = cardsAsync.value ?? [];
              // Mock logic: nếu cả thẻ và giao dịch đều rỗng thì dùng Mock
              if (txs.isEmpty && cardsData.isEmpty) {
                return const _TransactionItem(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Giao dịch mẫu 1',
                  subtitle: 'Shopee - Mua sắm',
                  amount: '-150.000đ',
                  time: 'Hôm nay',
                  isPositive: false,
                );
              }

              if (txs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'Chưa có giao dịch thực tế nào.',
                      style: GoogleFonts.inter(color: AppColors.textLight(context)),
                    ),
                  ),
                );
              }

              final currencyFormat = NumberFormat.currency(
                locale: 'vi_VN',
                symbol: 'đ',
              );

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: txs.length > 5 ? 5 : txs.length, // Lấy tối đa 5
                itemBuilder: (context, index) {
                  final tx = txs[index];
                  // Determine icon based on category
                  IconData catIcon;
                  switch (tx.category) {
                    case 'Mua sắm':
                      catIcon = Icons.shopping_bag_outlined;
                      break;
                    case 'Ăn uống':
                      catIcon = Icons.restaurant_rounded;
                      break;
                    case 'Di chuyển':
                      catIcon = Icons.directions_car_filled_outlined;
                      break;
                    case 'Giải trí':
                      catIcon = Icons.confirmation_number_outlined;
                      break;
                    case 'Hoá đơn':
                      catIcon = Icons.receipt_long_outlined;
                      break;
                    default:
                      catIcon = Icons.grid_view_rounded;
                      break;
                  }

                  final dateFormat = DateFormat('dd/MM HH:mm');
                  return _TransactionItem(
                    icon: catIcon,
                    title: tx.category,
                    subtitle: tx.note.isNotEmpty ? tx.note : tx.sourceName,
                    amount: '-${currencyFormat.format(tx.amount)}',
                    time: dateFormat.format(tx.timestamp),
                    isPositive: false,
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Text('Lỗi tải giao dịch'),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final VoidCallback? onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12, 
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String amount;
  final String time;
  final bool isPositive;

  const _TransactionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.time,
    this.isPositive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.textPrimary(context)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: AppColors.textLight(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w900,
                  color: isPositive
                      ? const Color(0xFF10B981)
                      : AppColors.textPrimary(context),
                ),
              ),
              Text(
                time,
                style: GoogleFonts.inter(
                  color: AppColors.textLight(context),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }
}
