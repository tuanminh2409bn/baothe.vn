import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../constants/app_styles.dart';
import '../../models/credit_card_model.dart';
import '../../models/user_card_model.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';

class CardFormScreen extends ConsumerStatefulWidget {
  final CreditCard baseCard;

  const CardFormScreen({super.key, required this.baseCard});

  @override
  ConsumerState<CardFormScreen> createState() => _CardFormScreenState();
}

class _CardFormScreenState extends ConsumerState<CardFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _limitController = TextEditingController();
  final _balanceController = TextEditingController();
  int _statementDay = 20;
  int _dueDay = 5;
  bool _isLoading = false;

  @override
  void dispose() {
    _limitController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final user = ref.read(authServiceProvider).currentUser;
    
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập')),
      );
      setState(() => _isLoading = false);
      return;
    }

    final userCard = UserCard(
      id: const Uuid().v4(),
      userId: user.uid,
      cardId: widget.baseCard.id,
      cardName: widget.baseCard.name,
      bankName: widget.baseCard.bankName,
      imagePath: widget.baseCard.imagePath,
      limit: double.tryParse(_limitController.text) ?? 0,
      balance: double.tryParse(_balanceController.text) ?? 0,
      statementDay: _statementDay,
      dueDay: _dueDay,
      createdAt: DateTime.now(),
    );

    try {
      await ref.read(firestoreServiceProvider).addUserCard(userCard);
      // Lên lịch nhắc nhở thanh toán
      await ref.read(notificationServiceProvider).schedulePaymentReminders(userCard);

      if (mounted) {
        context.go('/wallet');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã thêm thẻ vào ví thành công!'), backgroundColor: Colors.green),
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Chi Tiết Thẻ')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardPreview(),
              const SizedBox(height: 32),
              Text('Cấu hình hạn mức & số dư', style: AppStyles.h3),
              const SizedBox(height: 16),
              _buildTextField('Hạn mức thẻ (Credit Limit)', _limitController, 'Nhập số tiền hạn mức...'),
              const SizedBox(height: 20),
              _buildTextField('Số dư hiện tại (Số tiền đã dùng)', _balanceController, 'Nhập số tiền đã chi tiêu...'),
              const SizedBox(height: 32),
              Text('Chu kỳ thanh toán', style: AppStyles.h3),
              const SizedBox(height: 16),
              _buildDayPicker('Ngày chốt sao kê hàng tháng', _statementDay, (val) => setState(() => _statementDay = val!)),
              const SizedBox(height: 20),
              _buildDayPicker('Ngày đến hạn thanh toán', _dueDay, (val) => setState(() => _dueDay = val!)),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('Lưu vào ví', style: AppStyles.buttonText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppStyles.softShadow,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(widget.baseCard.imagePath, width: 100, height: 60, fit: BoxFit.cover),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.baseCard.name, style: AppStyles.h4),
                Text(widget.baseCard.bankName, style: AppStyles.labelSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppStyles.labelSmall.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3))),
          ),
          validator: (value) => value == null || value.isEmpty ? 'Vui lòng nhập số tiền' : null,
        ),
      ],
    );
  }

  Widget _buildDayPicker(String label, int currentValue, ValueChanged<int?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppStyles.labelSmall.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: currentValue,
              isExpanded: true,
              items: List.generate(31, (index) => index + 1)
                  .map((day) => DropdownMenuItem(value: day, child: Text('Ngày $day')))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
