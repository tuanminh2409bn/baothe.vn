import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../constants/app_styles.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../models/transaction_model.dart';

import '../../common_widgets/auth_placeholder.dart';

class SpendingScreen extends ConsumerWidget {
  const SpendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authServiceProvider);
    final user = auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: AuthPlaceholder(),
      );
    }

    final transactionsAsync = ref.watch(transactionsStreamProvider(user.uid));
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quản Lý Chi Tiêu'),
        actions: [
          IconButton(
            onPressed: () => context.push('/add-transaction'),
            icon: const Icon(Icons.add_box_outlined, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: transactionsAsync.when(
        data: (List<Transaction> transactions) {
          if (transactions.isEmpty) {
            return _buildEmptyState(context);
          }

          final totalSpent = transactions.fold<double>(0, (sum, item) => sum + item.amount);

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(transactionsStreamProvider(user.uid)),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildTotalSpentCard(totalSpent, currencyFormat),
                const SizedBox(height: 24),
                Text('Lịch sử giao dịch', style: AppStyles.h3),
                const SizedBox(height: 16),
                ...transactions.map((tx) => _buildTransactionItem(context, tx, currencyFormat, dateFormat)),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Lỗi: $e')),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 80, color: AppColors.textLight.withValues(alpha: 0.5)),
          const SizedBox(height: 20),
          Text('Chưa có giao dịch nào', style: AppStyles.h3),
          const SizedBox(height: 10),
          Text('Bắt đầu ghi chép chi tiêu để quản lý tài chính tốt hơn', style: AppStyles.labelSmall, textAlign: TextAlign.center),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => context.push('/add-transaction'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Thêm giao dịch đầu tiên', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSpentCard(double total, NumberFormat format) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppStyles.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tổng chi tiêu tháng này', style: AppStyles.labelSmall),
          const SizedBox(height: 8),
          Text(
            format.format(total),
            style: AppStyles.h1.copyWith(color: AppColors.primary, fontSize: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, Transaction tx, NumberFormat currencyFormat, DateFormat dateFormat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.background,
          child: Icon(_getCategoryIcon(tx.category), color: AppColors.primary, size: 20),
        ),
        title: Text(tx.category, style: AppStyles.h4),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dùng thẻ: ${tx.cardName}', style: const TextStyle(fontSize: 11)),
            Text(dateFormat.format(tx.timestamp), style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
          ],
        ),
        trailing: Text(
          '-${currencyFormat.format(tx.amount)}',
          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Ăn uống': return Icons.restaurant;
      case 'Mua sắm': return Icons.shopping_bag;
      case 'Di chuyển': return Icons.directions_car;
      case 'Giải trí': return Icons.movie;
      case 'Y tế': return Icons.medical_services;
      case 'Giáo dục': return Icons.school;
      default: return Icons.category;
    }
  }
}
