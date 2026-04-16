import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/credit_card_model.dart';

class ComparisonState extends Notifier<List<CreditCard>> {
  @override
  List<CreditCard> build() => [];

  // Thêm thẻ vào danh sách so sánh (Tối đa 4 thẻ)
  void addCard(CreditCard card) {
    if (state.length < 4 && !state.any((c) => c.id == card.id)) {
      state = [...state, card];
    }
  }

  // Xóa thẻ khỏi danh sách so sánh
  void removeCard(String cardId) {
    state = state.where((c) => c.id != cardId).toList();
  }

  // Xóa toàn bộ danh sách so sánh
  void clearAll() {
    state = [];
  }

  // Kiểm tra thẻ có trong danh sách so sánh chưa
  bool contains(String cardId) {
    return state.any((c) => c.id == cardId);
  }
}

final comparisonProvider = NotifierProvider<ComparisonState, List<CreditCard>>(() {
  return ComparisonState();
});
