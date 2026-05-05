import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../constants/app_styles.dart';
import '../../../services/firestore_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/user_wallet_model.dart';

class MobileAddWalletScreen extends ConsumerStatefulWidget {
  const MobileAddWalletScreen({super.key});

  @override
  ConsumerState<MobileAddWalletScreen> createState() => _MobileAddWalletScreenState();
}

class _MobileAddWalletScreenState extends ConsumerState<MobileAddWalletScreen> {
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  WalletType _selectedType = WalletType.cash;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _walletTypes = [
    {'type': WalletType.cash, 'label': 'Tiền mặt', 'icon': Icons.money_rounded},
    {'type': WalletType.bankAccount, 'label': 'Tài khoản Ngân hàng', 'icon': Icons.account_balance_rounded},
    {'type': WalletType.eWallet, 'label': 'Ví điện tử (MoMo, ZaloPay...)', 'icon': Icons.account_balance_wallet_rounded},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _onBalanceChanged(String value) {
    if (value.isEmpty) return;
    final cleanValue = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanValue.isEmpty) {
      _balanceController.text = '';
      return;
    }
    final double amount = double.parse(cleanValue);
    final formattedValue = NumberFormat.decimalPattern('vi_VN').format(amount);
    _balanceController.value = TextEditingValue(
      text: formattedValue,
      selection: TextSelection.collapsed(offset: formattedValue.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'THÊM VÍ MỚI',
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
            _buildSectionTitle('1. Tên ví / Tài khoản'),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _nameController,
              label: 'Ví dụ: Tiền mặt, Vietcombank, MoMo',
              hint: 'Tên gợi nhớ',
              icon: Icons.edit_note_rounded,
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('2. Số dư hiện tại'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: TextField(
                controller: _balanceController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: _onBalanceChanged,
                decoration: InputDecoration(
                  icon: Icon(Icons.attach_money_rounded, color: AppColors.textLight(context), size: 20),
                  labelText: 'Nhập số tiền hiện có',
                  hintText: '0',
                  suffixText: 'VNĐ',
                  border: InputBorder.none,
                  labelStyle: GoogleFonts.inter(color: AppColors.textSecondary(context), fontSize: 13),
                  hintStyle: GoogleFonts.inter(color: Colors.grey.shade300, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('3. Loại ví'),
            const SizedBox(height: 12),
            _buildTypeSelector(),
            const SizedBox(height: 48),
            _buildSaveButton(),
            // Khoảng trống bổ sung cho Android navigation bar
            const SizedBox(height: 40),
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
        color: AppColors.textSecondary(context),
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
        border: Border.all(color: AppColors.border(context)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          icon: Icon(icon, color: AppColors.textLight(context), size: 20),
          labelText: label,
          hintText: hint,
          border: InputBorder.none,
          labelStyle: GoogleFonts.inter(color: AppColors.textSecondary(context), fontSize: 13),
          hintStyle: GoogleFonts.inter(color: Colors.grey.shade300, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      children: _walletTypes.map((typeMap) {
        final type = typeMap['type'] as WalletType;
        final label = typeMap['label'] as String;
        final icon = typeMap['icon'] as IconData;
        final isSelected = _selectedType == type;

        return GestureDetector(
          onTap: () => setState(() => _selectedType = type),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary(context).withValues(alpha: 0.05) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.primary(context) : AppColors.border(context),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary(context) : AppColors.background(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: isSelected ? Colors.white : AppColors.textSecondary(context)),
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? AppColors.primary(context) : AppColors.textPrimary(context),
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: AppColors.primary(context)),
              ],
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
        onPressed: _isLoading ? null : _saveWallet,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoading 
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text(
            'TẠO VÍ NGAY',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white),
          ),
      ),
    );
  }

  Future<void> _saveWallet() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên ví')));
      return;
    }

    setState(() => _isLoading = true);
    final user = ref.read(authServiceProvider).currentUser;

    try {
      final wallet = UserWallet(
        id: const Uuid().v4(),
        userId: user!.uid,
        name: _nameController.text,
        balance: double.tryParse(_balanceController.text.replaceAll('.', '')) ?? 0.0,
        type: _selectedType,
        createdAt: DateTime.now(),
      );

      await ref.read(firestoreServiceProvider).addUserWallet(wallet);
      
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã tạo ví thành công!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
