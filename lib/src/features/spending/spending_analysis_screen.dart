import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../constants/app_styles.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../models/transaction_model.dart';
import 'package:intl/intl.dart';

import '../../common_widgets/auth_placeholder.dart';

class SpendingAnalysisScreen extends ConsumerWidget {
  const SpendingAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;
    if (user == null) {
      return const Scaffold(
        body: AuthPlaceholder(),
      );
    }

    final transactionsAsync = ref.watch(transactionsStreamProvider(user.uid));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Phân Tích Chi Tiêu')),
      body: transactionsAsync.when(
        data: (List<Transaction> transactions) {
          if (transactions.isEmpty) {
            return const Center(child: Text('Chưa có dữ liệu để phân tích'));
          }

          final categoryData = _processCategoryData(transactions);
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Chi tiêu theo hạng mục', style: AppStyles.h3),
                const SizedBox(height: 24),
                _buildPieChart(categoryData),
                const SizedBox(height: 40),
                Text('Chi tiết hạng mục', style: AppStyles.h3),
                const SizedBox(height: 16),
                ...categoryData.entries.map((e) => _buildCategoryRow(e.key, e.value, transactions.fold(0.0, (sum, item) => sum + item.amount))),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Lỗi: $e')),
      ),
    );
  }

  Map<String, double> _processCategoryData(List<Transaction> transactions) {
    Map<String, double> data = {};
    for (var tx in transactions) {
      data[tx.category] = (data[tx.category] ?? 0) + tx.amount;
    }
    return data;
  }

  Widget _buildPieChart(Map<String, double> data) {
    final colors = [
      Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, 
      Colors.teal, Colors.pink, Colors.amber, Colors.indigo, Colors.brown
    ];
    int colorIndex = 0;

    return SizedBox(
      height: 250,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 50,
          sections: data.entries.map((e) {
            final color = colors[colorIndex % colors.length];
            colorIndex++;
            return PieChartSectionData(
              color: color,
              value: e.value,
              title: '', // Không hiện title trực tiếp trên biểu đồ để sạch hơn
              radius: 60,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCategoryRow(String category, double amount, double total) {
    final percent = (amount / total * 100).toStringAsFixed(1);
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(category, style: AppStyles.bodyMedium)),
          Text(percent + '%', style: TextStyle(color: AppColors.textLight, fontSize: 12)),
          const SizedBox(width: 16),
          Text(currencyFormat.format(amount), style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
