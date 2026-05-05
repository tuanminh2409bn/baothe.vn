import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType {
  credit,
  personal,
}

class Transaction {
  final String id;
  final String userId;
  final String? userCardId; // ID của UserCard (nullable nếu là personal)
  final String? userWalletId; // ID của UserWallet (nullable nếu là credit)
  final String sourceName; // Tên thẻ hoặc ví đã sử dụng
  final double amount;
  final String category;
  final String note;
  final DateTime timestamp;
  final TransactionType type;

  Transaction({
    required this.id,
    required this.userId,
    this.userCardId,
    this.userWalletId,
    required this.sourceName,
    required this.amount,
    required this.category,
    this.note = '',
    required this.timestamp,
    this.type = TransactionType.credit,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userCardId': userCardId,
      'userWalletId': userWalletId,
      'sourceName': sourceName,
      'amount': amount,
      'category': category,
      'note': note,
      'timestamp': timestamp,
      'type': type.name,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userCardId: map['userCardId'],
      userWalletId: map['userWalletId'],
      // Hỗ trợ trường cardName cũ nếu sourceName chưa có
      sourceName: map['sourceName'] ?? map['cardName'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] ?? 'Khác',
      note: map['note'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      type: TransactionType.values.firstWhere(
        (e) => e.name == (map['type'] ?? 'credit'),
        orElse: () => TransactionType.credit,
      ),
    );
  }
}
