class CreditCard {
  final String id;
  final String name;
  final String bankName;
  final String imagePath;
  final String cashbackHighlight;
  final List<String> details;
  final String applyUrl;
  
  // Các trường thông tin bổ sung
  final double? annualFee;
  final double? interestRate;
  final String? cardType; // Visa, Mastercard, JCB, American Express
  final String? cardTier; // Classic, Gold, Platinum, Signature, Infinite
  final List<String>? benefits;
  final Map<String, dynamic>? requirements;
  final String? promoHighlight;

  CreditCard({
    required this.id,
    required this.name,
    required this.bankName,
    required this.imagePath,
    required this.cashbackHighlight,
    required this.details,
    this.applyUrl = '',
    this.annualFee,
    this.interestRate,
    this.cardType,
    this.cardTier,
    this.benefits,
    this.requirements,
    this.promoHighlight,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'bankName': bankName,
      'imagePath': imagePath,
      'cashbackHighlight': cashbackHighlight,
      'details': details,
      'applyUrl': applyUrl,
      'annualFee': annualFee,
      'interestRate': interestRate,
      'cardType': cardType,
      'cardTier': cardTier,
      'benefits': benefits,
      'requirements': requirements,
      'promoHighlight': promoHighlight,
    };
  }

  factory CreditCard.fromMap(Map<String, dynamic> map) {
    return CreditCard(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      bankName: map['bankName'] ?? '',
      imagePath: map['imagePath'] ?? '',
      cashbackHighlight: map['cashbackHighlight'] ?? '',
      details: List<String>.from(map['details'] ?? []),
      applyUrl: map['applyUrl'] ?? '',
      annualFee: (map['annualFee'] as num?)?.toDouble(),
      interestRate: (map['interestRate'] as num?)?.toDouble(),
      cardType: map['cardType'],
      cardTier: map['cardTier'],
      benefits: map['benefits'] != null ? List<String>.from(map['benefits']) : null,
      requirements: map['requirements'],
      promoHighlight: map['promoHighlight'],
    );
  }
}

// Dữ liệu mẫu mở rộng
final List<CreditCard> mockCards = [
  CreditCard(
    id: 'vcb-vibe',
    name: 'Vietcombank Vibe Platinum',
    bankName: 'Vietcombank',
    imagePath: 'assets/cards/vcb_vibe.png',
    cashbackHighlight: 'Tích điểm VIBE REWARDS x10 điểm thưởng',
    details: [
      'BẢO HIỂM CHUYẾN ĐI\nĐến 11,65 tỷ VND',
    ],
    annualFee: 800000,
    interestRate: 15.0,
    cardType: 'Visa',
    cardTier: 'Platinum',
    benefits: ['Hoàn tiền 10% tại siêu thị', 'Miễn phí phòng chờ sân bay'],
  ),
  CreditCard(
    id: 'vcb-cashplus',
    name: 'Vietcombank Cashplus Platinum American Express®',
    bankName: 'Vietcombank',
    imagePath: 'assets/cards/vcb_cashplus.png',
    cashbackHighlight: 'HOÀN TIỀN KHÔNG GIỚI HẠN\nĐến 1,5%',
    details: [
      'BẢO HIỂM CHUYẾN ĐI\nĐến 23,3 tỷ VND',
    ],
    annualFee: 1000000,
    cardType: 'American Express',
    cardTier: 'Platinum',
  ),
  CreditCard(
    id: 'vcb-mastercard',
    name: 'Vietcombank Mastercard® World',
    bankName: 'Vietcombank',
    imagePath: 'assets/cards/vcb_master.png',
    cashbackHighlight: 'HOÀN TIỀN CHI TIÊU NƯỚC NGOÀI\nĐẾN 5%',
    details: [
      'MIỄN LÃI\nĐến 55 ngày',
    ],
    annualFee: 1500000,
    cardType: 'Mastercard',
    cardTier: 'World',
  ),
];
