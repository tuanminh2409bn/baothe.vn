import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../constants/api_keys.dart';
import '../models/credit_card_model.dart';

final aiServiceProvider = Provider<AIService>((ref) {
  return AIService(FirebaseFirestore.instance);
});

class AIService {
  final FirebaseFirestore _firestore;
  List<CreditCard>? _cachedCards;
  List<CreditCard> _lastRecommendedCards = [];
  final List<Map<String, dynamic>> _history = [];

  AIService(this._firestore);

  void resetSession() {
    _history.clear();
    _lastRecommendedCards.clear();
  }

  List<CreditCard> get lastRecommendedCards => _lastRecommendedCards;

  Future<String> sendMessage(String text) async {
    _lastRecommendedCards.clear();
    const cleanKey = ApiKeys.geminiApiKey;
    try {
      if (_cachedCards == null) await _loadCardsToCache();

      _history.add({"role": "user", "parts": [{"text": text}]});

      const systemInstruction = '''Bạn là Finy AI - Chuyên gia Tài chính và Thẻ tín dụng thông minh nhất Việt Nam.
Nhiệm vụ của bạn là giúp người dùng TIẾT KIỆM TIỀN bằng cách chọn đúng thẻ tín dụng để tiêu dùng.

QUY TẮC TƯ VẤN:
1. KHI NGƯỜI DÙNG CÓ NHU CẦU CHI TIÊU:
   - Nhận diện danh mục (vd: mua trà sữa -> 'dining', mua sắm Tiki -> 'online').
   - LUÔN GỌI `findBestCards(category)` để lấy dữ liệu thực tế.
   - TRẢ LỜI THÔNG MINH: Giải thích rõ lý do tại sao thẻ đó tốt nhất (vd: "Thẻ này hoàn đến 10%, giúp bạn tiết kiệm 200k cho món đồ này").
2. PHÂN TÍCH TOÀN DIỆN: So sánh các thẻ dựa trên tỷ lệ hoàn tiền và hạn mức hoàn tối đa (maxCashback).
3. PHONG CÁCH: Chuyên nghiệp, nhạy bén, đáng tin cậy. Dùng ngôn ngữ tài chính cao cấp nhưng dễ hiểu.
4. ĐA DẠNG: Đề xuất thẻ từ nhiều ngân hàng khác nhau để người dùng có nhiều lựa chọn tốt nhất.
''';

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$cleanKey'
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": _history,
          "systemInstruction": {"parts": [{"text": systemInstruction}]},
          "tools": [{
            "function_declarations": [{
              "name": "findBestCards",
              "description": "Tìm kiếm các thẻ tín dụng có tỷ lệ hoàn tiền cao nhất theo từng hạng mục chi tiêu tại Việt Nam.",
              "parameters": {
                "type": "object",
                "properties": {
                  "category": {
                    "type": "string", 
                    "enum": ["supermarket", "online", "travel", "dining", "shopping", "medical", "education", "transport", "insurance", "utilities", "entertainment", "gym", "other"],
                    "description": "Hạng mục chi tiêu người dùng đang quan tâm (supermarket: Siêu thị, online: Mua sắm trực tuyến, travel: Du lịch/Máy bay, dining: Ăn uống, shopping: Mua sắm/TTMS, medical: Y tế, education: Giáo dục, transport: Giao thông/Xăng dầu, insurance: Bảo hiểm, utilities: Điện nước/Hóa đơn, entertainment: Giải trí/Xem phim, gym: Thể thao/Gym, other: Hoàn tiền chi tiêu chung)"
                  }
                },
                "required": ["category"]
              }
            }]
          }],
          "toolConfig": {
            "functionCallingConfig": {"mode": "AUTO"}
          }
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        print('AI Error: ${response.body}');
        return "Finy AI đang bận một chút để cập nhật dữ liệu thẻ mới nhất, bạn vui lòng thử lại sau vài giây nhé! (Lỗi: ${response.statusCode})";
      }

      final data = jsonDecode(response.body);
      final candidate = data['candidates'][0];
      final content = candidate['content'];
      
      if (content['parts'][0].containsKey('functionCall')) {
        final functionCall = content['parts'][0]['functionCall'];
        final String category = (functionCall['args']['category'] as String?)?.toLowerCase() ?? 'other';
        
        final cards = await _executeFindBestCards(category);
        _lastRecommendedCards = cards;

        // Lưu function call vào lịch sử
        _history.add(content);
        
        return _sendFunctionResponse(functionCall['name'], cards, category);
      }

      final String botReply = content['parts'][0]['text'] ?? 'Tôi có thể giúp bạn tìm thẻ tín dụng có ưu đãi hoàn tiền tốt nhất. Bạn định chi tiêu vào việc gì?';
      _history.add({"role": "model", "parts": [{"text": botReply}]});
      return botReply;

    } catch (e) {
      return "Finy đang bận xử lý dữ liệu thẻ, bạn hãy nhắn lại cho Finy nhé!";
    }
  }

  Future<String> _sendFunctionResponse(String functionName, List<CreditCard> cards, String category) async {
    const cleanKey = ApiKeys.geminiApiKey;
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$cleanKey');

    final Map<String, dynamic> functionResponsePart = {
      "role": "function",
      "parts": [{
        "functionResponse": {
          "name": functionName,
          "response": {
            "content": {
              "category": category,
              "top_cards": cards.map((c) => {
                'name': c.name, 
                'bank': c.bankName, 
                'cashback_rate': _getRate(c, category),
                'max_cashback': c.maxCashbackPerMonth
              }).toList()
            }
          }
        }
      }]
    };

    _history.add(functionResponsePart);

    final response = await http.post(
      url, 
      headers: {'Content-Type': 'application/json'}, 
      body: jsonEncode({
        "contents": _history,
      })
    );

    if (response.statusCode != 200) return "Finy đã tìm thấy thẻ nhưng gặp lỗi khi phân tích. Dưới đây là các thẻ tốt nhất cho bạn.";

    final data = jsonDecode(response.body);
    final String botReply = data['candidates'][0]['content']['parts'][0]['text'] ?? 'Dựa trên dữ liệu hoàn tiền, đây là những lựa chọn tốt nhất cho bạn:';
    
    _history.add({"role": "model", "parts": [{"text": botReply}]});
    return botReply;
  }

  Future<void> _loadCardsToCache() async {
    try {
      final snapshot = await _firestore.collection('cards').get();
      _cachedCards = snapshot.docs.map((doc) => CreditCard.fromMap(doc.data())).toList();
    } catch (e) { _cachedCards = []; }
  }

  Future<List<CreditCard>> _executeFindBestCards(String category) async {
    if (_cachedCards == null || _cachedCards!.isEmpty) await _loadCardsToCache();
    
    final allCards = List<CreditCard>.from(_cachedCards!);
    
    // 1. Lọc các thẻ có hoàn tiền cho danh mục này (> 0)
    final eligibleCards = allCards.where((c) => _getRate(c, category) > 0).toList();
    
    if (eligibleCards.isEmpty) {
      // Nếu không có thẻ nào hoàn tiền riêng cho mục này, lấy top 5 thẻ hoàn tiền "Hoàn tiền chi tiêu" (other)
      return allCards.take(5).toList();
    }

    // 2. Nhóm thẻ theo ngân hàng để đảm bảo tính đa dạng
    final Map<String, List<CreditCard>> cardsByBank = {};
    for (var card in eligibleCards) {
      if (!cardsByBank.containsKey(card.bankName)) {
        cardsByBank[card.bankName] = [];
      }
      cardsByBank[card.bankName]!.add(card);
    }

    // 3. Với mỗi ngân hàng, chọn ra thẻ TỐT NHẤT của họ cho danh mục này
    final List<CreditCard> bestPerBank = [];
    cardsByBank.forEach((bankName, bankCards) {
      // Sắp xếp thẻ của ngân hàng này theo tỷ lệ hoàn tiền giảm dần
      bankCards.sort((a, b) => _getRate(b, category).compareTo(_getRate(a, category)));
      bestPerBank.add(bankCards.first);
    });

    // 4. Sắp xếp danh sách "best-per-bank" theo tỷ lệ hoàn tiền giảm dần
    bestPerBank.sort((a, b) => _getRate(b, category).compareTo(_getRate(a, category)));

    // 5. Logic ĐỔI MỚI (Renewal):
    // - Lấy 3 ngân hàng có tỷ lệ hoàn tiền cao nhất (Top 1, 2, 3)
    // - Với các ngân hàng còn lại (từ Top 4 trở đi), lấy ngẫu nhiên 2 ngân hàng để tạo sự mới mẻ
    if (bestPerBank.length > 5) {
      final top3 = bestPerBank.take(3).toList();
      final others = bestPerBank.skip(3).toList()..shuffle();
      return [...top3, ...others.take(2)];
    }

    return bestPerBank;
  }

  double _getRate(CreditCard card, String category) {
    switch (category) {
      case 'supermarket': return card.supermarketCashbackRate ?? 0;
      case 'online': return card.onlineCashbackRate ?? 0;
      case 'travel': return card.travelCashbackRate ?? 0;
      case 'dining': return card.diningCashbackRate ?? 0;
      case 'shopping': return card.shoppingCashbackRate ?? 0;
      case 'medical': return card.medicalCashbackRate ?? 0;
      case 'education': return card.educationCashbackRate ?? 0;
      case 'transport': return card.transportCashbackRate ?? 0;
      case 'insurance': return card.insuranceCashbackRate ?? 0;
      case 'utilities': return card.utilitiesCashbackRate ?? 0;
      case 'entertainment': return card.entertainmentCashbackRate ?? 0;
      case 'gym': return card.gymCashbackRate ?? 0;
      default: return card.otherCashbackRate ?? 0;
    }
  }
}
