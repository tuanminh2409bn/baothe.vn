import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../constants/app_styles.dart';
import '../../services/firestore_service.dart';
import '../../models/credit_card_model.dart';

class AddCardScreen extends ConsumerStatefulWidget {
  const AddCardScreen({super.key});

  @override
  ConsumerState<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends ConsumerState<AddCardScreen> {
  String _searchQuery = '';
  String? _selectedBank;

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(cardsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Thêm Thẻ Mới'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              _buildSearchBar(),
              _buildBankFilter(),
            ],
          ),
        ),
      ),
      body: cardsAsync.when(
        data: (cards) {
          final filteredCards = cards.where((card) {
            final matchesSearch = card.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                card.bankName.toLowerCase().contains(_searchQuery.toLowerCase());
            final matchesBank = _selectedBank == null || card.bankName == _selectedBank;
            return matchesSearch && matchesBank;
          }).toList();

          if (filteredCards.isEmpty) {
            return const Center(child: Text('Không tìm thấy thẻ nào phù hợp'));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: filteredCards.length,
            itemBuilder: (context, index) {
              final card = filteredCards[index];
              return _buildCardTile(card);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Lỗi: $e')),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Tìm tên thẻ hoặc ngân hàng...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildBankFilter() {
    final banks = [
      'Vietcombank', 'VIB', 'Techcombank', 'VPBank', 'Sacombank', 
      'HSBC', 'ACB', 'TPBank', 'BIDV', 'VietinBank', 'Shinhan Bank'
    ];

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: banks.length + 1,
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final bank = isAll ? null : banks[index - 1];
          final isSelected = _selectedBank == bank;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(isAll ? 'Tất cả' : bank!),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _selectedBank = selected ? bank : null);
              },
              backgroundColor: Colors.white,
              selectedColor: AppColors.primary.withValues(alpha: 0.2),
              checkmarkColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: BorderSide(color: isSelected ? AppColors.primary : Colors.grey.withValues(alpha: 0.3)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCardTile(CreditCard card) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            card.imagePath,
            width: 80,
            height: 50,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 80,
              height: 50,
              color: AppColors.background,
              child: const Icon(Icons.credit_card, size: 20),
            ),
          ),
        ),
        title: Text(card.name, style: AppStyles.h4.copyWith(fontSize: 14)),
        subtitle: Text(card.bankName, style: AppStyles.labelSmall),
        trailing: const Icon(Icons.add_circle_outline, color: AppColors.primary),
        onTap: () {
          context.push('/card-form', extra: card);
        },
      ),
    );
  }
}
