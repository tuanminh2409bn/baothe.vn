import 'package:cloud_firestore/cloud_firestore.dart';

class Transaction {
  final String id;
  final String userId;
  final String userCardId; // ID của UserCard đã sử dụng
  final String cardName; // Cache tên thẻ để hiển thị nhanh
  final double amount;
  final String category;
  final String note;
  final DateTime timestamp;

  Transaction({
    required this.id,
    required this.userId,
    required this.userCardId,
    required this.cardName,
    required this.amount,
    required this.category,
    this.note = '',
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userCardId': userCardId,
      'cardName': cardName,
      'amount': amount,
      'category': category,
      'note': note,
      'timestamp': timestamp,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userCardId: map['userCardId'] ?? '',
      cardName: map['cardName'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] ?? 'Khác',
      note: map['note'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
}
