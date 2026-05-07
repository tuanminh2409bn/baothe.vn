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
import '../../../models/transaction_model.dart';
import '../../../models/user_card_model.dart';
import '../../../models/user_wallet_model.dart';
import '../../../utils/currency_formatter.dart';

class MobileAddTransactionScreen extends ConsumerStatefulWidget {
  final TransactionType type;
  const MobileAddTransactionScreen({super.key, required this.type});

  @override
  ConsumerState<MobileAddTransactionScreen> createState() => _MobileAddTransactionScreenState();
}

class _MobileAddTransactionScreenState extends ConsumerState<MobileAddTransactionScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  
  String? _selectedSourceId; 
  String _selectedCategory = 'Mua sắm';
  DateTime _selectedDateTime = DateTime.now();
  bool _isLoading = false;

  final List<Map<String, dynamic>> _categories = [
    {'label': 'Mua sắm', 'icon': Icons.shopping_bag_rounded},
    {'label': 'Ăn uống', 'icon': Icons.fastfood_rounded},
    {'label': 'Di chuyển', 'icon': Icons.directions_car_rounded},
    {'label': 'Giải trí', 'icon': Icons.movie_rounded},
    {'label': 'Hoá đơn', 'icon': Icons.receipt_long_rounded},
    {'label': 'Siêu thị', 'icon': Icons.local_grocery_store_rounded},
    {'label': 'Online', 'icon': Icons.language_rounded},
    {'label': 'Du lịch', 'icon': Icons.flight_takeoff_rounded},
    {'label': 'Y tế', 'icon': Icons.local_hospital_rounded},
    {'label': 'Giáo dục', 'icon': Icons.school_rounded},
    {'label': 'Bảo hiểm', 'icon': Icons.shield_rounded},
    {'label': 'Gym', 'icon': Icons.fitness_center_rounded},
    {'label': 'Spa/Làm đẹp', 'icon': Icons.spa_rounded},
    {'label': 'Chi tiêu', 'icon': Icons.more_horiz_rounded},
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String value) {
    if (value.isEmpty) return;
    
    // Xoá tất cả ký tự không phải số
    final cleanValue = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanValue.isEmpty) {
      _amountController.text = '';
      return;
    }

    final double amount = double.parse(cleanValue);
    final formattedValue = NumberFormat.decimalPattern('vi_VN').format(amount);
    
    // Cập nhật text và giữ vị trí con trỏ ở cuối
    _amountController.value = TextEditingValue(
      text: formattedValue,
      selection: TextSelection.collapsed(offset: formattedValue.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.read(authServiceProvider).currentUser;
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');
    
    // Watch đúng provider tùy theo loại
    final sourcesAsync = widget.type == TransactionType.credit
        ? (user != null ? ref.watch(userCardsStreamProvider(user.uid)) : const AsyncValue<List<UserCard>>.data([]))
        : (user != null ? ref.watch(userWalletsStreamProvider(user.uid)) : const AsyncValue<List<UserWallet>>.data([]));

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.type == TransactionType.credit ? 'CHI TIÊU QUA THẺ' : 'CHI TIÊU CÁ NHÂN',
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
            _buildAmountTextField(),
            const SizedBox(height: 32),
            _buildSectionTitle(widget.type == TransactionType.credit ? '2. Chọn thẻ thanh toán' : '2. Chọn nguồn tiền'),
            const SizedBox(height: 12),
            _buildSourceSelector(sourcesAsync),
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
            const SizedBox(height: 32),
            _buildSectionTitle('5. Thời gian chi tiêu'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDateTimePickerTile(
                    label: 'Ngày',
                    value: dateFormat.format(_selectedDateTime),
                    icon: Icons.calendar_today_rounded,
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDateTimePickerTile(
                    label: 'Giờ',
                    value: timeFormat.format(_selectedDateTime),
                    icon: Icons.access_time_rounded,
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
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

  Widget _buildAmountTextField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: TextField(
        controller: _amountController,
        keyboardType: TextInputType.number,
        inputFormatters: [CurrencyInputFormatter()],
        onChanged: _onAmountChanged,
        style: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: widget.type == TransactionType.credit ? AppColors.primary(context) : Colors.green.shade700,
        ),
        decoration: InputDecoration(
          icon: Icon(
            Icons.attach_money_rounded, 
            color: widget.type == TransactionType.credit ? AppColors.primary(context) : Colors.green.shade700, 
            size: 28
          ),
          labelText: 'Nhập số tiền',
          hintText: '0',
          suffixText: 'VNĐ',
          suffixStyle: GoogleFonts.inter(color: AppColors.textLight(context), fontWeight: FontWeight.bold),
          border: InputBorder.none,
          labelStyle: GoogleFonts.inter(color: AppColors.textSecondary(context), fontSize: 13),
          hintStyle: GoogleFonts.inter(color: Colors.grey.shade300, fontSize: 24),
        ),
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

  Widget _buildDateTimePickerTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight(context))),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context)),
                ),
                Icon(icon, size: 16, color: AppColors.textLight(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: widget.type == TransactionType.credit ? AppColors.primary(context) : Colors.green.shade700,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDateTime.hour,
          _selectedDateTime.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: widget.type == TransactionType.credit ? AppColors.primary(context) : Colors.green.shade700,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDateTime = DateTime(
          _selectedDateTime.year,
          _selectedDateTime.month,
          _selectedDateTime.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Widget _buildSourceSelector(AsyncValue<List<dynamic>> sourcesAsync) {
    return sourcesAsync.when(
      data: (sources) {
        if (_selectedSourceId != null && !sources.any((s) => s.id == _selectedSourceId)) {
          Future.microtask(() {
            if (mounted) setState(() => _selectedSourceId = null);
          });
        }

        if (sources.isEmpty) {
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
                    widget.type == TransactionType.credit 
                      ? 'Bạn chưa có thẻ nào. Hãy thêm thẻ trước.'
                      : 'Bạn chưa có ví nào. Hãy tạo ví trước.',
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
            border: Border.all(color: AppColors.border(context)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedSourceId,
              hint: Text(widget.type == TransactionType.credit ? 'Chọn thẻ thanh toán' : 'Chọn nguồn tiền'),
              isExpanded: true,
              items: sources.map((source) {
                String label;
                if (source is UserCard) {
                  label = '${source.bankName} - ${source.cardName}';
                } else if (source is UserWallet) {
                  label = source.name;
                } else {
                  label = 'Không xác định';
                }
                return DropdownMenuItem<String>(
                  value: source.id,
                  child: Text(label),
                );
              }).toList(),
              onChanged: (id) => setState(() => _selectedSourceId = id),
            ),
          ),
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (_, __) => const Text('Lỗi tải dữ liệu'),
    );
  }

  Widget _buildCategorySelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _categories.map<Widget>((cat) {
        final label = cat['label'] as String;
        final icon = cat['icon'] as IconData;
        final isSelected = _selectedCategory == label;
        
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = label),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary(context) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary(context) : AppColors.border(context),
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: AppColors.primary(context).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ] : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? Colors.white : AppColors.textSecondary(context),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isSelected ? Colors.white : AppColors.textPrimary(context),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
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
        onPressed: _isLoading ? null : _saveTransaction,
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.type == TransactionType.credit ? AppColors.primary(context) : Colors.green.shade700,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoading 
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text(
            widget.type == TransactionType.credit ? 'THÊM CHI TIÊU THẺ' : 'THÊM CHI TIÊU CÁ NHÂN',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white),
          ),
      ),
    );
  }

  Future<void> _saveTransaction() async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    if (_selectedSourceId == null || _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập đủ số tiền và chọn nguồn tiền')));
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
      String sourceName = '';
      if (widget.type == TransactionType.credit) {
        final cards = ref.read(userCardsStreamProvider(user.uid)).value ?? [];
        sourceName = cards.firstWhere((c) => c.id == _selectedSourceId).cardName;
      } else {
        final wallets = ref.read(userWalletsStreamProvider(user.uid)).value ?? [];
        sourceName = wallets.firstWhere((w) => w.id == _selectedSourceId).name;
      }

      final tx = Transaction(
        id: const Uuid().v4(),
        userId: user.uid,
        userCardId: widget.type == TransactionType.credit ? _selectedSourceId : null,
        userWalletId: widget.type == TransactionType.personal ? _selectedSourceId : null,
        sourceName: sourceName,
        amount: amount,
        category: _selectedCategory,
        note: _noteController.text,
        timestamp: _selectedDateTime,
        type: widget.type,
      );

      await ref.read(firestoreServiceProvider).addTransaction(tx);
      
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thêm chi tiêu thành công')));
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
