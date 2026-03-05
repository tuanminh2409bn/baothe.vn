import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/credit_card_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Lấy danh sách tất cả các thẻ
  Stream<List<CreditCard>> getCards() {
    return _db.collection('cards').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => CreditCard.fromMap(doc.data())).toList());
  }

  // Lấy chi tiết một thẻ theo ID
  Future<CreditCard?> getCardById(String id) async {
    final doc = await _db.collection('cards').doc(id).get();
    if (doc.exists && doc.data() != null) {
      return CreditCard.fromMap(doc.data()!);
    }
    return null;
  }

  // Thêm hoặc cập nhật thẻ (Dùng cho tool scraping hoặc admin)
  Future<void> saveCard(CreditCard card) async {
    await _db.collection('cards').doc(card.id).set(card.toMap());
  }
}

// Provider để truy cập Firestore Service
final firestoreServiceProvider = Provider((ref) => FirestoreService());

// Provider cung cấp danh sách thẻ (Stream)
final cardsStreamProvider = StreamProvider<List<CreditCard>>((ref) {
  return ref.watch(firestoreServiceProvider).getCards();
});

// Provider cung cấp thông tin chi tiết một thẻ (Future)
final cardDetailProvider = FutureProvider.family<CreditCard?, String>((ref, id) {
  return ref.watch(firestoreServiceProvider).getCardById(id);
});
