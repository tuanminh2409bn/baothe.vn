import 'dart:convert';
import 'dart:math';
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
  List<Map<String, dynamic>> _history = [];

  AIService(this._firestore);

  void resetSession() {
    _history.clear();
    _lastRecommendedCards.clear();
  }

  List<CreditCard> get lastRecommendedCards => _lastRecommendedCards;

  Future<String> sendMessage(String text) async {
    final cleanKey = ApiKeys.geminiApiKey.trim();
    try {
      if (_cachedCards == null) await _loadCardsToCache();

      _history.add({"role": "user", "parts": [{"text": text}]});

      final systemInstruction = '''Bạn là Finy AI - Chuyên gia Tài chính Cao cấp.
Nhiệm vụ: Phân tích nhu cầu và đề xuất các dòng thẻ tín dụng đa dạng tại Việt Nam.

QUY TẮC:
1. Luôn ưu tiên các ngân hàng có ưu đãi hoàn tiền cao nhất cho nhu cầu người dùng.
2. PHẢI đề xuất đa dạng ngân hàng (không chỉ tập trung vào 1-2 ngân hàng).
3. LUÔN GỌI hàm `findBestCards` nếu người dùng hỏi về bất kỳ loại chi tiêu/ưu đãi nào.
4. Trả lời cực ngắn gọn (dưới 25 từ), sang trọng. 
   VD: "Finy đã phân tích và tuyển chọn 5 dòng thẻ tối ưu từ các ngân hàng khác nhau cho nhu cầu của bạn:"
5. Các thẻ gợi ý sẽ được hiển thị ngay bên dưới lời nhắn này.
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
            "functionDeclarations": [{
              "name": "findBestCards",
              "description": "Tìm kiếm thẻ tín dụng từ kho dữ liệu đa dạng.",
              "parameters": {
                "type": "object",
                "properties": {
                  "category": {
                    "type": "string", 
                    "enum": ["supermarket", "online", "travel", "dining", "shopping", "medical", "education", "transport", "insurance", "utilities", "entertainment", "gym"],
                    "description": "Danh mục chi tiêu"
                  }
                },
                "required": ["category"]
              }
            }]
          }]
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return "Finy AI đang bảo trì, vui lòng quay lại sau.";

      final data = jsonDecode(response.body);
      final candidate = data['candidates'][0];
      final content = candidate['content'];
      
      if (content['parts'][0].containsKey('functionCall')) {
        final functionCall = content['parts'][0]['functionCall'];
        final String category = (functionCall['args']['category'] as String?)?.toLowerCase() ?? 'online';
        
        final cards = await _executeFindBestCards(category);
        _lastRecommendedCards = cards;

        return _sendFunctionResponse(functionCall['name'], cards, category);
      }

      final String botReply = content['parts'][0]['text'] ?? 'Tôi có thể hỗ trợ bạn tìm thẻ hoàn tiền phù hợp. Bạn đang quan tâm đến mục chi tiêu nào?';
      _history.add({"role": "model", "parts": [{"text": botReply}]});
      return botReply;

    } catch (e) {
      return "Kết nối mạng không ổn định, Finy chưa thể phản hồi ngay lúc này.";
    }
  }

  Future<String> _sendFunctionResponse(String functionName, List<CreditCard> cards, String category) async {
    final cleanKey = ApiKeys.geminiApiKey.trim();
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$cleanKey');

    final contentsWithFunction = List<Map<String, dynamic>>.from(_history);
    contentsWithFunction.add({
      "role": "model",
      "parts": [{"functionCall": {"name": functionName, "args": {"category": category}}}]
    });

    contentsWithFunction.add({
      "role": "function",
      "parts": [{
        "functionResponse": {
          "name": functionName,
          "response": {
            "name": functionName,
            "content": {
              "found": cards.length,
              "category": category,
              "cards": cards.map((c) => {'name': c.name, 'bank': c.bankName}).toList()
            }
          }
        }
      }]
    });

    final response = await http.post(
      url, 
      headers: {'Content-Type': 'application/json'}, 
      body: jsonEncode({"contents": contentsWithFunction})
    );

    final data = jsonDecode(response.body);
    final String botReply = data['candidates'][0]['content']['parts'][0]['text'] ?? 'Đây là danh sách các thẻ đa dạng phù hợp với nhu cầu của bạn:';
    
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
    
    // Sắp xếp thẻ tốt nhất cho category này lên đầu
    allCards.sort((a, b) => _getRate(b, category).compareTo(_getRate(a, category)));
    
    // Lấy đúng 3 thẻ (Vẫn ưu tiên thẻ tốt nhất nhưng trộn thêm ngân hàng khác nếu có cùng mức ưu đãi)
    final bestMatch = allCards.where((c) => _getRate(c, category) > 0).toList();
    
    if (bestMatch.length >= 3) {
      // Nếu có nhiều thẻ tốt, lấy 2 thẻ đầu và random 1 thẻ trong số các thẻ tốt còn lại để tạo sự tươi mới
      final top2 = bestMatch.take(2).toList();
      final remainingBest = bestMatch.skip(2).toList()..shuffle();
      return [...top2, ...remainingBest.take(1)];
    }

    return allCards.take(3).toList();
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
