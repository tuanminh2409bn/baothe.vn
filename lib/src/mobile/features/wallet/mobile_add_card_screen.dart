import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/app_styles.dart';
import '../../../services/firestore_service.dart';
import '../../../models/credit_card_model.dart';
import '../../../models/user_card_model.dart';
import '../../../services/auth_service.dart';
import 'package:uuid/uuid.dart';

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
            const SizedBox(height: 32),
            _buildSectionTitle('2. Thông tin hạn mức'),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _limitController,
              label: 'Hạn mức thẻ',
              hint: 'Ví dụ: 50.000.000',
              icon: Icons.account_balance_wallet_outlined,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _balanceController,
              label: 'Dư nợ hiện tại (nếu có)',
              hint: '0',
              icon: Icons.money_off_csred_outlined,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('3. Chu kỳ thanh toán'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildNumberPicker(
                    label: 'Ngày sao kê',
                    value: _statementDay,
                    onChanged: (v) => setState(() => _statementDay = v),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildNumberPicker(
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
              Image.network(_selectedTemplate!.imagePath, width: 24, height: 24, errorBuilder: (_, __, ___) => const Icon(Icons.credit_card))
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
                              leading: Image.network(card.imagePath, width: 32, errorBuilder: (_, __, ___) => const Icon(Icons.credit_card)),
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
                      error: (_, __) => const Text('Lỗi tải dữ liệu'),
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

  Widget _buildNumberPicker({required String label, required int value, required ValueChanged<int> onChanged}) {
    return Container(
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
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              isDense: true,
              items: List.generate(31, (i) => i + 1).map((i) {
                return DropdownMenuItem(value: i, child: Text('Ngày $i'));
              }).toList(),
              onChanged: (v) => v != null ? onChanged(v) : null,
            ),
          ),
        ],
      ),
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
    );

    await ref.read(firestoreServiceProvider).addUserCard(newCard);
    if (mounted) Navigator.pop(context);
  }
}
