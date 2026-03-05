import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/credit_card_model.dart';

class ComparisonState extends StateNotifier<List<CreditCard>> {
  ComparisonState() : super([]);

  // Thêm thẻ vào danh sách so sánh (Tối đa 4 thẻ)
  void addCard(CreditCard card) {
    if (state.length < 4 && !state.any((c) => c.id == card.id)) {
      state = [...state, card];
    }
  }

  // Xóa thẻ khỏi danh sách so sánh
  void removeCard(String cardId) {
    state = state.where((card) => card.id != cardId).toList();
  }

  // Xóa toàn bộ danh sách so sánh
  void clearAll() {
    state = [];
  }

  // Kiểm tra thẻ có trong danh sách so sánh chưa
  bool contains(String cardId) {
    return state.any((card) => card.id == cardId);
  }
}

final comparisonProvider = StateNotifierProvider<ComparisonState, List<CreditCard>>((ref) {
  return ComparisonState();
});
