import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../constants/app_styles.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../models/transaction_model.dart';
import '../../models/user_card_model.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _selectedCategory = 'Ăn uống';
  UserCard? _selectedCard;
  bool _isLoading = false;

  final List<String> _categories = [
    'Ăn uống', 'Mua sắm', 'Di chuyển', 'Giải trí', 'Y tế', 'Giáo dục', 'Grab/Xanh SM', 'Shopee/Lazada', 'Tiền điện/nước', 'Khác'
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0 || _selectedCard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền và chọn thẻ thanh toán')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final user = ref.read(authServiceProvider).currentUser;

    final tx = Transaction(
      id: const Uuid().v4(),
      userId: user!.uid,
      userCardId: _selectedCard!.id,
      sourceName: _selectedCard!.cardName,
      amount: amount,
      category: _selectedCategory,
      note: _noteController.text,
      timestamp: DateTime.now(),
      type: TransactionType.credit,
    );

    try {
      await ref.read(firestoreServiceProvider).addTransaction(tx);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã ghi chép chi tiêu thành công!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authServiceProvider).currentUser;
    final userCardsAsync = ref.watch(userCardsStreamProvider(user!.uid));

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(title: const Text('Thêm Giao Dịch')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAmountInput(),
            const SizedBox(height: 32),
            Text('Hạng mục', style: AppStyles.h3(context)),
            const SizedBox(height: 12),
            _buildCategoryGrid(),
            const SizedBox(height: 32),
            Text('Chọn thẻ thanh toán', style: AppStyles.h3(context)),
            const SizedBox(height: 12),
            userCardsAsync.when(
              data: (cards) {
                if (cards.isEmpty) {
                  return _buildNoCardsMessage();
                }
                return _buildCardSelector(cards);
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, st) => Text('Lỗi tải danh sách thẻ: $e'),
            ),
            const SizedBox(height: 32),
            _buildNoteInput(),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary(context),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text('Lưu giao dịch', style: AppStyles.buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Số tiền', style: AppStyles.labelSmall(context)),
        const SizedBox(height: 8),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary(context)),
          decoration: const InputDecoration(
            hintText: '0',
            suffixText: '₫',
            border: InputBorder.none,
          ),
        ),
        const Divider(thickness: 1),
      ],
    );
  }

  Widget _buildCategoryGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((cat) {
        final isSelected = _selectedCategory == cat;
        return ChoiceChip(
          label: Text(cat),
          selected: isSelected,
          onSelected: (selected) => setState(() => _selectedCategory = cat),
          selectedColor: AppColors.primary(context).withValues(alpha: 0.2),
          labelStyle: TextStyle(
            color: isSelected ? AppColors.primary(context) : AppColors.textPrimary(context),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCardSelector(List<UserCard> cards) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        itemBuilder: (context, index) {
          final card = cards[index];
          final isSelected = _selectedCard?.id == card.id;
          return GestureDetector(
            onTap: () => setState(() => _selectedCard = card),
            child: Container(
              width: 180,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary(context) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSelected ? AppColors.primary(context) : Colors.grey.withValues(alpha: 0.3)),
                boxShadow: isSelected ? AppStyles.softShadow : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    card.cardName,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    card.bankName,
                    style: TextStyle(
                      color: isSelected ? Colors.white.withValues(alpha: 0.8) : AppColors.textLight(context),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoCardsMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Bạn chưa có thẻ nào trong ví. Vui lòng thêm thẻ trước khi ghi chép chi tiêu.',
        style: TextStyle(color: Colors.orange, fontSize: 13),
      ),
    );
  }

  Widget _buildNoteInput() {
    return TextField(
      controller: _noteController,
      decoration: InputDecoration(
        labelText: 'Ghi chú (tùy chọn)',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3))),
      ),
    );
  }
}
