import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/app_styles.dart';
import '../../../services/firestore_service.dart';
import '../../../models/credit_card_model.dart';
import '../../../models/user_card_model.dart';
import '../../../services/auth_service.dart';
import 'package:uuid/uuid.dart';

/// TextInputFormatter tự động thêm dấu chấm phần nghìn
class ThousandSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Chỉ giữ lại số
    final digitsOnly = newValue.text.replaceAll('.', '');
    if (digitsOnly.isEmpty) return newValue.copyWith(text: '');

    // Định dạng dấu chấm phần nghìn
    final buffer = StringBuffer();
    int count = 0;
    for (int i = digitsOnly.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write('.');
      buffer.write(digitsOnly[i]);
      count++;
    }
    final formatted = buffer.toString().split('').reversed.join('');

    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class MobileAddCardScreen extends ConsumerStatefulWidget {
  const MobileAddCardScreen({super.key});

  @override
  ConsumerState<MobileAddCardScreen> createState() => _MobileAddCardScreenState();
}

class _MobileAddCardScreenState extends ConsumerState<MobileAddCardScreen> {
  final _limitController = TextEditingController();
  final _balanceController = TextEditingController();
  final _searchController = TextEditingController();
  CreditCard? _selectedTemplate;
  int _statementDay = 20;
  int _dueDay = 5;
  String _searchQuery = "";

  @override
  void dispose() {
    _limitController.dispose();
    _balanceController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(cardsStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'THÊM THẺ MỚI',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.2),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('1. Chọn loại thẻ'),
            const SizedBox(height: 12),
            _buildCardSelector(cardsAsync),

            // --- Hiển thị ưu đãi sau khi chọn thẻ ---
            if (_selectedTemplate != null) ...[
              const SizedBox(height: 16),
              _buildCardBenefitsPreview(_selectedTemplate!),
            ],

            const SizedBox(height: 32),
            _buildSectionTitle('2. Thông tin hạn mức'),
            const SizedBox(height: 12),
            _buildCurrencyField(
              controller: _limitController,
              label: 'Hạn mức thẻ',
              hint: 'Ví dụ: 50.000.000',
              icon: Icons.account_balance_wallet_outlined,
            ),
            const SizedBox(height: 16),
            _buildCurrencyField(
              controller: _balanceController,
              label: 'Dư nợ hiện tại (nếu có)',
              hint: '0',
              icon: Icons.money_off_csred_outlined,
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('3. Chu kỳ thanh toán'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDayPickerTile(
                    label: 'Ngày sao kê',
                    value: _statementDay,
                    onChanged: (v) => setState(() => _statementDay = v),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDayPickerTile(
                    label: 'Ngày đến hạn',
                    value: _dueDay,
                    onChanged: (v) => setState(() => _dueDay = v),
                  ),
                ),
              ],
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

  Widget _buildCardSelector(AsyncValue<List<CreditCard>> cardsAsync) {
    return InkWell(
      onTap: () => _showCardSearchDialog(cardsAsync),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        child: Row(
          children: [
            if (_selectedTemplate != null)
              Image.network(_selectedTemplate!.imagePath, width: 24, height: 24,
                  errorBuilder: (_, _, _) => const Icon(Icons.credit_card))
            else
              const Icon(Icons.search_rounded, color: AppColors.textLight),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedTemplate != null
                    ? '${_selectedTemplate!.bankName} - ${_selectedTemplate!.name}'
                    : 'Bấm để tìm và chọn loại thẻ',
                style: TextStyle(
                  color: _selectedTemplate != null ? AppColors.textPrimary : AppColors.textLight,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }

  /// Widget xem trước ưu đãi thẻ sau khi chọn
  Widget _buildCardBenefitsPreview(CreditCard card) {
    final highlights = <Map<String, dynamic>>[];
    
    // Thêm các tỷ lệ hoàn tiền cao nhất vào highlights
    final cashbackRates = [
      {'label': 'Siêu thị', 'rate': card.supermarketCashbackRate},
      {'label': 'Online', 'rate': card.onlineCashbackRate},
      {'label': 'Ẩm thực', 'rate': card.diningCashbackRate},
      {'label': 'Du lịch', 'rate': card.travelCashbackRate},
      {'label': 'Di chuyển', 'rate': card.transportCashbackRate},
      {'label': 'Y tế', 'rate': card.medicalCashbackRate},
      {'label': 'Giáo dục', 'rate': card.educationCashbackRate},
      {'label': 'Mua sắm', 'rate': card.shoppingCashbackRate},
      {'label': 'Hóa đơn', 'rate': card.utilitiesCashbackRate},
      {'label': 'Giải trí', 'rate': card.entertainmentCashbackRate},
      {'label': 'Gym', 'rate': card.gymCashbackRate},
      {'label': 'Bảo hiểm', 'rate': card.insuranceCashbackRate},
      {'label': 'Khác', 'rate': card.otherCashbackRate},
    ].where((c) => (c['rate'] as double? ?? 0) > 0).toList();

    // Sắp xếp giảm dần theo tỷ lệ hoàn tiền
    cashbackRates.sort((a, b) => (b['rate'] as double).compareTo(a['rate'] as double));

    // Lấy tối đa 2 hạng mục cao nhất để hiển thị nổi bật
    for (var cat in cashbackRates.take(2)) {
      highlights.add({
        'icon': Icons.flash_on_rounded, 
        'color': Colors.amber.shade700, 
        'text': 'Hoàn tiền ${cat['label']}: ${cat['rate']}%'
      });
    }

    if (card.cashbackHighlight.isNotEmpty) {
      highlights.add({'icon': Icons.local_offer_rounded, 'color': Colors.orange, 'text': card.cashbackHighlight});
    }

    if (highlights.isEmpty && (card.benefits == null || card.benefits!.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Ưu đãi nổi bật của thẻ',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final h in highlights) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(h['icon'] as IconData, size: 14, color: (h['color'] as Color)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    h['text'] as String,
                    style: GoogleFonts.inter(fontSize: 13, height: 1.4, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (card.benefits != null && card.benefits!.isNotEmpty) ...[
            const Divider(height: 12, color: Color(0xFFE8E2D9)),
            ...card.benefits!.take(3).map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(b, style: GoogleFonts.inter(fontSize: 12, height: 1.4, color: AppColors.textSecondary)),
                    ),
                  ],
                ),
              ),
            ),
            if (card.benefits!.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+ ${card.benefits!.length - 3} quyền lợi khác...',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textLight, fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _showCardSearchDialog(AsyncValue<List<CreditCard>> cardsAsync) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 24),
                  Text('TÌM KIẾM THẺ', style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 1)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    onChanged: (v) => setModalState(() => _searchQuery = v.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Nhập tên ngân hàng hoặc tên thẻ...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: cardsAsync.when(
                      data: (cards) {
                        final filtered = cards.where((c) =>
                          c.bankName.toLowerCase().contains(_searchQuery) ||
                          c.name.toLowerCase().contains(_searchQuery)
                        ).toList();
                        return ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final card = filtered[index];
                            return ListTile(
                              leading: Image.network(card.imagePath, width: 32,
                                  errorBuilder: (_, _, _) => const Icon(Icons.credit_card)),
                              title: Text(card.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(card.bankName),
                              onTap: () {
                                setState(() => _selectedTemplate = card);
                                Navigator.pop(context);
                              },
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (_, _) => const Text('Lỗi tải dữ liệu'),
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

  /// Ô nhập tiền tệ có định dạng dấu chấm phân nghìn tự động
  Widget _buildCurrencyField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
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
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          ThousandSeparatorFormatter(),
        ],
        decoration: InputDecoration(
          icon: Icon(icon, color: AppColors.textLight, size: 20),
          labelText: label,
          hintText: hint,
          suffixText: 'đ',
          suffixStyle: GoogleFonts.inter(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
          border: InputBorder.none,
          labelStyle: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
          hintStyle: GoogleFonts.inter(color: Colors.grey.shade300, fontSize: 14),
        ),
      ),
    );
  }

  /// Nút chọn ngày hiển thị dạng bảng lưới (grid)
  Widget _buildDayPickerTile({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return GestureDetector(
      onTap: () => _showDayGridPicker(label: label, currentValue: value, onChanged: onChanged),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ngày $value',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textLight),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Bảng chọn ngày dạng lưới số (1 - 31)
  void _showDayGridPicker({
    required String label,
    required int currentValue,
    required ValueChanged<int> onChanged,
  }) {
    int tempSelected = currentValue;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1,
                  ),
                  itemCount: 31,
                  itemBuilder: (_, index) {
                    final day = index + 1;
                    final isSelected = day == tempSelected;
                    return GestureDetector(
                      onTap: () {
                        setSheet(() => tempSelected = day);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$day',
                          style: GoogleFonts.inter(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      onChanged(tempSelected);
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text('Xác nhận ngày $tempSelected',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _saveCard,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: Text(
          'LƯU VÀO VÍ',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _saveCard() async {
    if (_selectedTemplate == null || _limitController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn thẻ và nhập hạn mức')));
      return;
    }

    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    final newCard = UserCard(
      id: const Uuid().v4(),
      userId: user.uid,
      cardId: _selectedTemplate!.id,
      cardName: _selectedTemplate!.name,
      bankName: _selectedTemplate!.bankName,
      imagePath: _selectedTemplate!.imagePath,
      limit: double.tryParse(_limitController.text.replaceAll('.', '')) ?? 0,
      balance: double.tryParse(_balanceController.text.replaceAll('.', '')) ?? 0,
      statementDay: _statementDay,
      dueDay: _dueDay,
      createdAt: DateTime.now(),
      // Copy cashback rates from template
      supermarketCashbackRate: _selectedTemplate!.supermarketCashbackRate,
      onlineCashbackRate: _selectedTemplate!.onlineCashbackRate,
      travelCashbackRate: _selectedTemplate!.travelCashbackRate,
      diningCashbackRate: _selectedTemplate!.diningCashbackRate,
      medicalCashbackRate: _selectedTemplate!.medicalCashbackRate,
      educationCashbackRate: _selectedTemplate!.educationCashbackRate,
      transportCashbackRate: _selectedTemplate!.transportCashbackRate,
      shoppingCashbackRate: _selectedTemplate!.shoppingCashbackRate,
      insuranceCashbackRate: _selectedTemplate!.insuranceCashbackRate,
      utilitiesCashbackRate: _selectedTemplate!.utilitiesCashbackRate,
      entertainmentCashbackRate: _selectedTemplate!.entertainmentCashbackRate,
      gymCashbackRate: _selectedTemplate!.gymCashbackRate,
      otherCashbackRate: _selectedTemplate!.otherCashbackRate,
      maxCashbackPerMonth: _selectedTemplate!.maxCashbackPerMonth,
      );

      await ref.read(firestoreServiceProvider).addUserCard(newCard);    if (mounted) Navigator.pop(context);
  }
}
