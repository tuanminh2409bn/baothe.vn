import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_styles.dart';
import '../../../services/firestore_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/user_card_model.dart';
import '../../../models/transaction_model.dart';

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

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _buildWalletHeader(userCardsAsync),
            const SizedBox(height: 20),
            _buildCreditCardSlider(userCardsAsync),
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
    final user = ref.watch(authServiceProvider).currentUser;
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary,
            child: Text(user?.email?.substring(0, 1).toUpperCase() ?? 'U', style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chào buổi sáng,', 
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              Text(user?.email?.split('@')[0] ?? 'Người dùng', 
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
        ],
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

  Widget _buildWalletHeader(AsyncValue<List<UserCard>> cardsAsync) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tổng dư nợ hiện tại',
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          cardsAsync.when(
            data: (cards) {
              final isMock = cards.isEmpty;
              final total = isMock ? 45200000.0 : cards.fold<double>(0, (sum, item) => sum + item.balance);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        currencyFormat.format(total),
                        style: GoogleFonts.inter(
                          fontSize: 32, 
                          fontWeight: FontWeight.w900, 
                          color: AppColors.textPrimary,
                          letterSpacing: -1,
                        ),
                      ),
                      if (isMock) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'DEMO',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange.shade700),
                          ),
                        ),
                      ],
                    ],
                  ).animate().fadeIn().slideX(begin: -0.1),
                  if (isMock)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Đây là dữ liệu mẫu. Mời bạn thêm thẻ thật để quản lý.',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.orange.shade700, fontWeight: FontWeight.w500),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn(duration: 1000.ms),
                    ),
                ],
              );
            },
            loading: () => const SizedBox(height: 40, width: 100, child: LinearProgressIndicator()),
            error: (_, __) => const Text('Lỗi tải dữ liệu'),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditCardSlider(AsyncValue<List<UserCard>> cardsAsync) {
    return cardsAsync.when(
      data: (cards) {
        final itemCount = cards.isEmpty ? 3 : cards.length;
        return Column(
          children: [
            SizedBox(
              height: 220,
              child: PageView.builder(
                controller: _cardController,
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  if (cards.isEmpty) {
                    return _buildMockCreditCardItem(index);
                  }
                  return _buildCreditCardItem(cards[index], index);
                },
              ),
            ),
            const SizedBox(height: 16),
            SmoothPageIndicator(
              controller: _cardController,
              count: itemCount,
              effect: const ExpandingDotsEffect(
                dotHeight: 6,
                dotWidth: 6,
                activeDotColor: AppColors.primary,
                dotColor: AppColors.border,
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Text('Lỗi tải thẻ'),
    );
  }

  Widget _buildMockCreditCardItem(int index) {
    final mockCards = [
      {'name': 'VIB Online Plus 2in1', 'bank': 'VIB Bank', 'limit': '24.500.000đ', 'type': 'VISA PLATINUM'},
      {'name': 'Techcombank Signature', 'bank': 'Techcombank', 'limit': '150.000.000đ', 'type': 'VISA SIGNATURE'},
      {'name': 'VPBank StepUp', 'bank': 'VPBank', 'limit': '50.000.000đ', 'type': 'MASTERCARD'},
    ];
    
    final card = mockCards[index];

    return Container(
      margin: const EdgeInsets.only(right: 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: index == 0 
            ? [const Color(0xFF1E293B), const Color(0xFF0F172A)] 
            : index == 1 
              ? [AppColors.primary, const Color(0xFF2D241E)]
              : [const Color(0xFF4338CA), const Color(0xFF312E81)],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 10)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(FontAwesomeIcons.braille, size: 150, color: Colors.white.withValues(alpha: 0.05)),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.contactless_outlined, color: Colors.white70),
                    Text(card['type']!, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.54), fontSize: 10, letterSpacing: 2)),
                  ],
                ),
                const Spacer(),
                Text(
                  card['name']!,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  card['bank']!,
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('HẠN MỨC CÒN LẠI', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.54), fontSize: 10)),
                        Text(card['limit']!, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Icon(Icons.credit_card, color: Colors.white),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().scale(delay: (index * 100).ms);
  }

  Widget _buildCreditCardItem(UserCard card, int index) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    return Container(
      margin: const EdgeInsets.only(right: 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: index % 2 == 0 
            ? [const Color(0xFF1E293B), const Color(0xFF0F172A)] 
            : [AppColors.primary, const Color(0xFF2D241E)],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 10)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(FontAwesomeIcons.braille, size: 150, color: Colors.white.withValues(alpha: 0.05)),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.contactless_outlined, color: Colors.white70),
                    Text('CREDIT CARD', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.54), fontSize: 10, letterSpacing: 2)),
                  ],
                ),
                const Spacer(),
                Text(
                  card.cardName,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  card.bankName,
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DƯ NỢ HIỆN TẠI', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.54), fontSize: 10)),
                        Text(currencyFormat.format(card.balance), style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    if (card.imagePath.isNotEmpty)
                      Image.network(card.imagePath, height: 24, errorBuilder: (_, __, ___) => const Icon(Icons.credit_card, color: Colors.white))
                    else
                      const Icon(Icons.credit_card, color: Colors.white),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().scale(delay: (index * 100).ms);
  }

  Widget _buildQuickActions(AsyncValue<List<UserCard>> cardsAsync) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _QuickActionButton(
            icon: Icons.add_rounded, 
            label: 'Chi tiêu', 
            color: const Color(0xFFEFF6FF), 
            iconColor: Colors.blue,
            onTap: () {
              cardsAsync.maybeWhen(
                data: (cards) {
                  if (cards.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vui lòng thêm thẻ (ví thật) trước khi thêm chi tiêu.'))
                    );
                  } else {
                    context.push('/add-transaction');
                  }
                },
                orElse: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng thử lại sau.'))
                ),
              );
            },
          ),
          _QuickActionButton(
            icon: Icons.wallet_rounded, 
            label: 'Thanh toán', 
            color: const Color(0xFFFFF7ED), 
            iconColor: Colors.orange,
            onTap: () => context.push('/wallet'),
          ),
          _QuickActionButton(
            icon: Icons.analytics_rounded, 
            label: 'Báo cáo', 
            color: const Color(0xFFFAF5FF), 
            iconColor: Colors.purple,
            onTap: () => context.push('/reports'),
          ),
          _QuickActionButton(
            icon: Icons.grid_view_rounded, 
            label: 'Khác', 
            color: const Color(0xFFF0FDF4), 
            iconColor: Colors.green,
            onTap: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
                builder: (context) => Container(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('TÍNH NĂNG KHÁC', style: GoogleFonts.inter(fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 24),
                      const ListTile(leading: Icon(Icons.compare_arrows_rounded), title: Text('So sánh thẻ')),
                      const ListTile(leading: Icon(Icons.calculate_outlined), title: Text('Công cụ tính toán')),
                      const ListTile(leading: Icon(Icons.star_outline_rounded), title: Text('Thẻ yêu thích')),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(
    AsyncValue<List<Transaction>> txAsync, 
    AsyncValue<List<UserCard>> cardsAsync
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Giao dịch gần đây', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(onPressed: () {}, child: const Text('Xem tất cả')),
            ],
          ),
          const SizedBox(height: 10),
          
          txAsync.when(
            data: (txs) {
              final cardsData = cardsAsync.valueOrNull ?? [];
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
                    child: Text('Chưa có giao dịch thực tế nào.', style: GoogleFonts.inter(color: AppColors.textLight)),
                  ),
                );
              }

              final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
              
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: txs.length > 5 ? 5 : txs.length, // Lấy tối đa 5
                itemBuilder: (context, index) {
                  final tx = txs[index];
                  // Determine icon based on category
                  IconData catIcon;
                  switch (tx.category) {
                    case 'Mua sắm': catIcon = Icons.shopping_bag_outlined; break;
                    case 'Ăn uống': catIcon = Icons.restaurant_rounded; break;
                    case 'Di chuyển': catIcon = Icons.directions_car_filled_outlined; break;
                    case 'Giải trí': catIcon = Icons.confirmation_number_outlined; break;
                    case 'Hoá đơn': catIcon = Icons.receipt_long_outlined; break;
                    default: catIcon = Icons.grid_view_rounded; break;
                  }

                  final dateFormat = DateFormat('dd/MM HH:mm');
                  return _TransactionItem(
                    icon: catIcon,
                    title: tx.category,
                    subtitle: tx.note.isNotEmpty ? tx.note : tx.cardName,
                    amount: '-${currencyFormat.format(tx.amount)}',
                    time: dateFormat.format(tx.timestamp),
                    isPositive: false,
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Text('Lỗi tải giao dịch'),
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
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500)),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(subtitle, style: GoogleFonts.inter(color: AppColors.textLight, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount, style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: isPositive ? const Color(0xFF10B981) : AppColors.textPrimary)),
              Text(time, style: GoogleFonts.inter(color: AppColors.textLight, fontSize: 11)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }
}
