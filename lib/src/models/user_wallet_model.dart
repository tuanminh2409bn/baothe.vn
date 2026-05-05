import 'package:cloud_firestore/cloud_firestore.dart';

enum WalletType {
  cash,
  bankAccount,
  eWallet,
}

class UserWallet {
  final String id;
  final String userId;
  final String name;
  final double balance;
  final WalletType type;
  final String? iconData;
  final int? colorValue;
  final DateTime createdAt;

  UserWallet({
    required this.id,
    required this.userId,
    required this.name,
    required this.balance,
    required this.type,
    this.iconData,
    this.colorValue,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'balance': balance,
      'type': type.name,
      'iconData': iconData,
      'colorValue': colorValue,
      'createdAt': createdAt,
    };
  }

  factory UserWallet.fromMap(Map<String, dynamic> map) {
    return UserWallet(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      type: WalletType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => WalletType.cash,
      ),
      iconData: map['iconData'],
      colorValue: map['colorValue'],
      createdAt: map['createdAt'] is Timestamp 
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  UserWallet copyWith({
    String? name,
    double? balance,
    WalletType? type,
    String? iconData,
    int? colorValue,
  }) {
    return UserWallet(
      id: id,
      userId: userId,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      type: type ?? this.type,
      iconData: iconData ?? this.iconData,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt,
    );
  }
}
