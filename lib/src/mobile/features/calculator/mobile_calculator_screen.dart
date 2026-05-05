import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_styles.dart';
import '../../../models/user_card_model.dart';
import '../../../services/firestore_service.dart';
import '../../../services/auth_service.dart';

class MobileCalculatorScreen extends ConsumerStatefulWidget {
  const MobileCalculatorScreen({super.key});

  @override
  ConsumerState<MobileCalculatorScreen> createState() => _MobileCalculatorScreenState();
}

class _MobileCalculatorScreenState extends ConsumerState<MobileCalculatorScreen> {
  UserCard? _selectedCard;
  final Map<String, TextEditingController> _controllers = {};
  double _totalCashback = 0;

  final List<Map<String, String>> _categories = [
    {'id': 'supermarketCashbackRate', 'label': 'Siêu thị'},
    {'id': 'diningCashbackRate', 'label': 'Ẩm thực'},
    {'id': 'onlineCashbackRate', 'label': 'Online/Mua sắm'},
    {'id': 'travelCashbackRate', 'label': 'Du lịch'},
    {'id': 'transportCashbackRate', 'label': 'Di chuyển'},
    {'id': 'otherCashbackRate', 'label': 'Hoàn tiền chi tiêu'},
  ];

  @override
  void initState() {
    super.initState();
    for (var cat in _categories) {
      _controllers[cat['id']!] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _calculateCashback() {
    if (_selectedCard == null) return;
    
    double total = 0;
    _controllers.forEach((id, controller) {
      final amount = double.tryParse(controller.text.replaceAll('.', '')) ?? 0;
      final rate = _getCashbackRate(_selectedCard!, id);
      total += (amount * rate) / 100;
    });

    setState(() {
      _totalCashback = total;
    });
  }

  double _getCashbackRate(UserCard card, String categoryId) {
    switch (categoryId) {
      case 'supermarketCashbackRate': return card.supermarketCashbackRate ?? 0;
      case 'onlineCashbackRate': return card.onlineCashbackRate ?? 0;
      case 'travelCashbackRate': return card.travelCashbackRate ?? 0;
      case 'diningCashbackRate': return card.diningCashbackRate ?? 0;
      case 'otherCashbackRate': return card.otherCashbackRate ?? 0;
      case 'transportCashbackRate': return card.transportCashbackRate ?? 0;
      default: return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authServiceProvider).currentUser;
    final userCardsAsync = user != null
        ? ref.watch(userCardsStreamProvider(user.uid))
        : const AsyncValue<List<UserCard>>.data([]);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
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
            'CÔNG CỤ TÍNH TOÁN',
            style: GoogleFonts.inter(
              color: AppColors.textPrimary(context),
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          bottom: TabBar(
            isScrollable: true,
            labelColor: AppColors.primary(context),
            unselectedLabelColor: AppColors.textLight(context),
            indicatorColor: AppColors.primary(context),
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(text: 'Hoàn tiền'),
              Tab(text: 'Lãi suất'),
              Tab(text: 'Trả góp'),
              Tab(text: 'Rút tiền'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildCashbackTab(context, userCardsAsync),
            _buildLegacyTab(context, 'Tính lãi suất trả thiểu'),
            _buildLegacyTab(context, 'Tính phí chuyển đổi trả góp'),
            _buildLegacyTab(context, 'Tính phí rút tiền mặt'),
          ],
        ),
      ),
    );
  }

  Widget _buildCashbackTab(BuildContext context, AsyncValue<List<UserCard>> cardsAsync) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1. CHỌN THẺ CẦN TÍNH',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.textSecondary(context), letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          _buildCardSelector(context, cardsAsync),
          const SizedBox(height: 32),
          Text(
            '2. NHẬP CHI TIÊU DỰ KIẾN (VNĐ)',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.textSecondary(context), letterSpacing: 0.5),
          ),
          const SizedBox(height: 16),
          ..._categories.map((cat) => _buildSpendingInput(context, cat['label']!, cat['id']!)),
          const SizedBox(height: 32),
          _buildResultSection(context, currencyFormat),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCardSelector(BuildContext context, AsyncValue<List<UserCard>> cardsAsync) {
    return cardsAsync.when(
      data: (cards) {
        if (cards.isEmpty) return const Text('Bạn chưa có thẻ nào.');
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<UserCard>(
              value: _selectedCard,
              hint: const Text('Chọn thẻ trong ví'),
              isExpanded: true,
              items: cards.map((card) => DropdownMenuItem(
                value: card,
                child: Text('${card.bankName} - ${card.cardName}'),
              )).toList(),
              onChanged: (card) {
                setState(() {
                  _selectedCard = card;
                  _calculateCashback();
                });
              },
            ),
          ),
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (_, _) => const Text('Lỗi tải thẻ'),
    );
  }

  Widget _buildSpendingInput(BuildContext context, String label, String id) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _controllers[id],
        keyboardType: TextInputType.number,
        onChanged: (_) => _calculateCashback(),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary(context)),
          suffixText: 'đ',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildResultSection(BuildContext context, NumberFormat format) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.primary(context).withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Text(
            'TỔNG TIỀN ĐƯỢC HOÀN',
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            format.format(_totalCashback),
            style: GoogleFonts.inter(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Text(
            'Dựa trên tỷ lệ hoàn tiền thực tế của thẻ',
            style: GoogleFonts.inter(color: Colors.white60, fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildLegacyTab(BuildContext context, String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction_rounded, size: 64, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.textSecondary(context))),
          const SizedBox(height: 8),
          Text('Tính năng đang được phát triển nâng cao.', style: GoogleFonts.inter(color: AppColors.textLight(context), fontSize: 13)),
        ],
      ),
    );
  }
}
