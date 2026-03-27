import 'package:cloud_firestore/cloud_firestore.dart';

class UserCard {
  final String id;
  final String userId;
  final String cardId; // Tham chiếu đến ID thẻ gốc trong bộ sưu tập 'cards'
  final String cardName;
  final String bankName;
  final String imagePath;
  final double limit;
  final double balance;
  final int statementDay; // Ngày chốt sao kê (1-31)
  final int dueDay; // Ngày hạn thanh toán (1-31)
  final DateTime createdAt;

  UserCard({
    required this.id,
    required this.userId,
    required this.cardId,
    required this.cardName,
    required this.bankName,
    required this.imagePath,
    required this.limit,
    required this.balance,
    required this.statementDay,
    required this.dueDay,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'cardId': cardId,
      'cardName': cardName,
      'bankName': bankName,
      'imagePath': imagePath,
      'limit': limit,
      'balance': balance,
      'statementDay': statementDay,
      'dueDay': dueDay,
      'createdAt': createdAt,
    };
  }

  factory UserCard.fromMap(Map<String, dynamic> map) {
    return UserCard(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      cardId: map['cardId'] ?? '',
      cardName: map['cardName'] ?? '',
      bankName: map['bankName'] ?? '',
      imagePath: map['imagePath'] ?? '',
      limit: (map['limit'] as num?)?.toDouble() ?? 0.0,
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      statementDay: map['statementDay'] ?? 1,
      dueDay: map['dueDay'] ?? 15,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  UserCard copyWith({
    double? limit,
    double? balance,
    int? statementDay,
    int? dueDay,
  }) {
    return UserCard(
      id: id,
      userId: userId,
      cardId: cardId,
      cardName: cardName,
      bankName: bankName,
      imagePath: imagePath,
      limit: limit ?? this.limit,
      balance: balance ?? this.balance,
      statementDay: statementDay ?? this.statementDay,
      dueDay: dueDay ?? this.dueDay,
      createdAt: createdAt,
    );
  }
}
