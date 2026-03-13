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

  // Dữ liệu chi tiết từ trang ngân hàng
  final List<Map<String, String>>? benefitsDetail;
  final List<Map<String, String>>? conditionsDetail;
  final List<Map<String, String>>? productInfoDetail;
  final List<Map<String, String>>? feeDetail;

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
    this.benefitsDetail,
    this.conditionsDetail,
    this.productInfoDetail,
    this.feeDetail,
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
      'benefitsDetail': benefitsDetail,
      'conditionsDetail': conditionsDetail,
      'productInfoDetail': productInfoDetail,
      'feeDetail': feeDetail,
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
      benefitsDetail: map['benefitsDetail'] != null 
          ? List<Map<String, String>>.from((map['benefitsDetail'] as List).map((e) => Map<String, String>.from(e)))
          : null,
      conditionsDetail: map['conditionsDetail'] != null 
          ? List<Map<String, String>>.from((map['conditionsDetail'] as List).map((e) => Map<String, String>.from(e)))
          : null,
      productInfoDetail: map['productInfoDetail'] != null 
          ? List<Map<String, String>>.from((map['productInfoDetail'] as List).map((e) => Map<String, String>.from(e)))
          : null,
      feeDetail: map['feeDetail'] != null 
          ? List<Map<String, String>>.from((map['feeDetail'] as List).map((e) => Map<String, String>.from(e)))
          : null,
    );
  }
}
