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

  // 14 Cashback Categories (Đồng bộ từ CreditCard)
  final double? supermarketCashbackRate;
  final double? onlineCashbackRate;
  final double? travelCashbackRate;
  final double? diningCashbackRate;
  final double? medicalCashbackRate;
  final double? educationCashbackRate;
  final double? transportCashbackRate;
  final double? shoppingCashbackRate;
  final double? insuranceCashbackRate;
  final double? utilitiesCashbackRate;
  final double? entertainmentCashbackRate;
  final double? gymCashbackRate;
  final double? otherCashbackRate;
  final double? maxCashbackPerMonth;

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
    this.supermarketCashbackRate,
    this.onlineCashbackRate,
    this.travelCashbackRate,
    this.diningCashbackRate,
    this.medicalCashbackRate,
    this.educationCashbackRate,
    this.transportCashbackRate,
    this.shoppingCashbackRate,
    this.insuranceCashbackRate,
    this.utilitiesCashbackRate,
    this.entertainmentCashbackRate,
    this.gymCashbackRate,
    this.otherCashbackRate,
    this.maxCashbackPerMonth,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserCard &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          cardId == other.cardId &&
          cardName == other.cardName &&
          bankName == other.bankName &&
          imagePath == other.imagePath &&
          limit == other.limit &&
          balance == other.balance &&
          statementDay == other.statementDay &&
          dueDay == other.dueDay &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      userId.hashCode ^
      cardId.hashCode ^
      cardName.hashCode ^
      bankName.hashCode ^
      imagePath.hashCode ^
      limit.hashCode ^
      balance.hashCode ^
      statementDay.hashCode ^
      dueDay.hashCode ^
      createdAt.hashCode;

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
      'supermarketCashbackRate': supermarketCashbackRate,
      'onlineCashbackRate': onlineCashbackRate,
      'travelCashbackRate': travelCashbackRate,
      'diningCashbackRate': diningCashbackRate,
      'medicalCashbackRate': medicalCashbackRate,
      'educationCashbackRate': educationCashbackRate,
      'transportCashbackRate': transportCashbackRate,
      'shoppingCashbackRate': shoppingCashbackRate,
      'insuranceCashbackRate': insuranceCashbackRate,
      'utilitiesCashbackRate': utilitiesCashbackRate,
      'entertainmentCashbackRate': entertainmentCashbackRate,
      'gymCashbackRate': gymCashbackRate,
      'otherCashbackRate': otherCashbackRate,
      'maxCashbackPerMonth': maxCashbackPerMonth,
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
      createdAt: map['createdAt'] is Timestamp 
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      supermarketCashbackRate: (map['supermarketCashbackRate'] as num?)?.toDouble(),
      onlineCashbackRate: (map['onlineCashbackRate'] as num?)?.toDouble(),
      travelCashbackRate: (map['travelCashbackRate'] as num?)?.toDouble(),
      diningCashbackRate: (map['diningCashbackRate'] as num?)?.toDouble(),
      medicalCashbackRate: (map['medicalCashbackRate'] as num?)?.toDouble(),
      educationCashbackRate: (map['educationCashbackRate'] as num?)?.toDouble(),
      transportCashbackRate: (map['transportCashbackRate'] as num?)?.toDouble(),
      shoppingCashbackRate: (map['shoppingCashbackRate'] as num?)?.toDouble(),
      insuranceCashbackRate: (map['insuranceCashbackRate'] as num?)?.toDouble(),
      utilitiesCashbackRate: (map['utilitiesCashbackRate'] as num?)?.toDouble(),
      entertainmentCashbackRate: (map['entertainmentCashbackRate'] as num?)?.toDouble(),
      gymCashbackRate: (map['gymCashbackRate'] as num?)?.toDouble(),
      otherCashbackRate: (map['otherCashbackRate'] as num?)?.toDouble(),
      maxCashbackPerMonth: (map['maxCashbackPerMonth'] as num?)?.toDouble(),
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
      supermarketCashbackRate: supermarketCashbackRate,
      onlineCashbackRate: onlineCashbackRate,
      travelCashbackRate: travelCashbackRate,
      diningCashbackRate: diningCashbackRate,
      medicalCashbackRate: medicalCashbackRate,
      educationCashbackRate: educationCashbackRate,
      transportCashbackRate: transportCashbackRate,
      shoppingCashbackRate: shoppingCashbackRate,
      insuranceCashbackRate: insuranceCashbackRate,
      utilitiesCashbackRate: utilitiesCashbackRate,
      entertainmentCashbackRate: entertainmentCashbackRate,
      gymCashbackRate: gymCashbackRate,
      otherCashbackRate: otherCashbackRate,
      maxCashbackPerMonth: maxCashbackPerMonth,
    );
  }
}
