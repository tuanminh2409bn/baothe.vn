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

  // 14 Cashback Categories (13 specific + 1 general "Chi tiêu")
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
  final double? otherCashbackRate; // Known as 'Chi tiêu' in UI

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
