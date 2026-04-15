import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../constants/app_styles.dart';
import '../../../services/firestore_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/transaction_model.dart';
import '../../../models/user_card_model.dart';

class MobileAddTransactionScreen extends ConsumerStatefulWidget {
  const MobileAddTransactionScreen({super.key});

  @override
  ConsumerState<MobileAddTransactionScreen> createState() => _MobileAddTransactionScreenState();
}

class _MobileAddTransactionScreenState extends ConsumerState<MobileAddTransactionScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  
  String? _selectedCardId; // Thay thế _selectedCard kiểu UserCard? thành _selectedCardId kiểu String?
  String _selectedCategory = 'Mua sắm';
  bool _isLoading = false;

  final List<String> _categories = [
    'Mua sắm',
    'Ăn uống',
    'Di chuyển',
    'Giải trí',
    'Hoá đơn',
    'Khác'
  ];

  @override
  Widget build(BuildContext context) {
    final user = ref.read(authServiceProvider).currentUser;
    final userCardsAsync = user != null 
        ? ref.watch(userCardsStreamProvider(user.uid))
        : const AsyncValue<List<UserCard>>.data([]);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'THÊM CHI TIÊU',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.2),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('1. Số tiền chi tiêu'),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _amountController,
              label: 'Nhập số tiền',
              hint: 'Ví dụ: 1.500.000',
              icon: Icons.attach_money_rounded,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('2. Chọn thẻ thanh toán'),
            const SizedBox(height: 12),
            _buildCardSelector(userCardsAsync),
            const SizedBox(height: 32),
            _buildSectionTitle('3. Chọn danh mục'),
            const SizedBox(height: 12),
            _buildCategorySelector(),
            const SizedBox(height: 32),
            _buildSectionTitle('4. Ghi chú (Tuỳ chọn)'),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _noteController,
              label: 'Mô tả chi tiêu',
              hint: 'Ví dụ: Mua sắm cuối tuần',
              icon: Icons.notes_rounded,
            ),
            const SizedBox(height: 48),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        color: AppColors.textSecondary,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          icon: Icon(icon, color: AppColors.textLight, size: 20),
          labelText: label,
          hintText: hint,
          border: InputBorder.none,
          labelStyle: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
          hintStyle: GoogleFonts.inter(color: Colors.grey.shade300, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildCardSelector(AsyncValue<List<UserCard>> cardsAsync) {
    return cardsAsync.when(
      data: (cards) {
        // Kiểm tra xem ID đã chọn còn trong danh sách không
        if (_selectedCardId != null && !cards.any((c) => c.id == _selectedCardId)) {
          Future.microtask(() {
            if (mounted) setState(() => _selectedCardId = null);
          });
        }

        if (cards.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Bạn chưa có thẻ nào trong ví. Hãy thêm thẻ trước.',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.orange.shade800),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF3F4F6)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCardId,
              hint: const Text('Chọn thẻ thanh toán'),
              isExpanded: true,
              items: cards.map((card) {
                return DropdownMenuItem<String>(
                  value: card.id,
                  child: Text('${card.bankName} - ${card.cardName}'),
                );
              }).toList(),
              onChanged: (id) => setState(() => _selectedCardId = id),
            ),
          ),
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (_, __) => const Text('Lỗi tải thẻ'),
    );
  }

  Widget _buildCategorySelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((cat) {
        final isSelected = _selectedCategory == cat;
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = cat),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? AppColors.primary : const Color(0xFFF3F4F6)),
            ),
            child: Text(
              cat,
              style: GoogleFonts.inter(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveTransaction,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoading 
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text(
            'THÊM CHI TIÊU',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white),
          ),
      ),
    );
  }

  Future<void> _saveTransaction() async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    final cards = ref.read(userCardsStreamProvider(user.uid)).valueOrNull ?? [];
    final selectedCard = cards.any((c) => c.id == _selectedCardId) 
        ? cards.firstWhere((c) => c.id == _selectedCardId)
        : null;

    if (selectedCard == null || _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập đủ số tiền và chọn thẻ')));
      return;
    }

    final amountStr = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = double.tryParse(amountStr) ?? 0;
    
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Số tiền không hợp lệ')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final tx = Transaction(
        id: const Uuid().v4(),
        userId: user.uid,
        userCardId: selectedCard.id,
        cardName: selectedCard.cardName,
        amount: amount,
        category: _selectedCategory,
        note: _noteController.text,
        timestamp: DateTime.now(),
      );

      await ref.read(firestoreServiceProvider).addTransaction(tx);
      
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thêm chi tiêu thành công')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Có lỗi xảy ra, vui lòng thử lại')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
