import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/credit_card_model.dart';
import '../models/user_card_model.dart';
import '../models/user_wallet_model.dart';
import '../models/transaction_model.dart';
import 'auth_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- USERS ---
  
  // Lưu thông tin user
  Future<void> saveUser(User user, {String? name, String? email, String? photoUrl}) async {
    final userDoc = _db.collection('users').doc(user.uid);
    final snapshot = await userDoc.get();
    
    // Tìm email từ các provider nếu user.email bị null
    String? finalEmail = email ?? user.email;
    String? finalPhotoUrl = photoUrl ?? user.photoURL;

    if (user.providerData.isNotEmpty) {
      for (var providerInfo in user.providerData) {
        if (finalEmail == null && providerInfo.email != null) {
          finalEmail = providerInfo.email;
        }
        if (finalPhotoUrl == null && providerInfo.photoURL != null) {
          finalPhotoUrl = providerInfo.photoURL;
        }
      }
    }
    
    if (!snapshot.exists) {
      await userDoc.set({
        'uid': user.uid,
        'email': finalEmail,
        'displayName': name ?? user.displayName,
        'photoURL': finalPhotoUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } else {
      await userDoc.update({
        'lastLoginAt': FieldValue.serverTimestamp(),
        if (name != null || user.displayName != null) 'displayName': name ?? user.displayName,
        if (finalEmail != null) 'email': finalEmail,
        if (finalPhotoUrl != null) 'photoURL': finalPhotoUrl,
      });
    }
  }

  // --- PUBLIC CARDS (Scraped) ---
  
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

  // --- USER CARDS (Wallet) ---

  // Lấy danh sách thẻ của một user cụ thể
  Stream<List<UserCard>> getUserCards(String userId) {
    return _db
        .collection('user_cards')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => UserCard.fromMap(doc.data())).toList());
  }

  // Thêm thẻ mới vào ví của user
  Future<void> addUserCard(UserCard card) async {
    await _db.collection('user_cards').doc(card.id).set(card.toMap());
  }

  // --- USER WALLETS ---

  // Lấy danh sách ví của một user
  Stream<List<UserWallet>> getUserWallets(String userId) {
    return _db
        .collection('user_wallets')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => UserWallet.fromMap(doc.data())).toList());
  }

  // Thêm ví mới
  Future<void> addUserWallet(UserWallet wallet) async {
    await _db.collection('user_wallets').doc(wallet.id).set(wallet.toMap());
  }

  // --- TRANSACTIONS (Spending) ---

  // Lấy lịch sử giao dịch của user
  Stream<List<Transaction>> getTransactions(String userId) {
    return _db
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Transaction.fromMap(doc.data())).toList());
  }

  // Thêm giao dịch mới
  Future<void> addTransaction(Transaction transaction) async {
    // 1. Lưu giao dịch
    await _db.collection('transactions').doc(transaction.id).set(transaction.toMap());

    // 2. Cập nhật số dư
    if (transaction.type == TransactionType.credit && transaction.userCardId != null) {
      // Thẻ tín dụng: Tăng nợ (balance)
      final cardRef = _db.collection('user_cards').doc(transaction.userCardId!);
      await _db.runTransaction((tx) async {
        final snapshot = await tx.get(cardRef);
        if (snapshot.exists) {
          final currentBalance = (snapshot.data()?['balance'] as num?)?.toDouble() ?? 0.0;
          tx.update(cardRef, {'balance': currentBalance + transaction.amount});
        }
      });
    } else if (transaction.type == TransactionType.personal && transaction.userWalletId != null) {
      // Ví cá nhân: Giảm số dư (balance)
      final walletRef = _db.collection('user_wallets').doc(transaction.userWalletId!);
      await _db.runTransaction((tx) async {
        final snapshot = await tx.get(walletRef);
        if (snapshot.exists) {
          final currentBalance = (snapshot.data()?['balance'] as num?)?.toDouble() ?? 0.0;
          tx.update(walletRef, {'balance': currentBalance - transaction.amount});
        }
      });
    }
  }

  // Lấy thông tin profile người dùng
  Stream<Map<String, dynamic>?> getUserProfile(String userId) {
    return _db.collection('users').doc(userId).snapshots().map((doc) => doc.data());
  }
}

// Provider để truy cập Firestore Service
final firestoreServiceProvider = Provider((ref) => FirestoreService());

// Provider cung cấp thông tin profile người dùng
final userProfileProvider = StreamProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, userId) {
  return ref.watch(firestoreServiceProvider).getUserProfile(userId);
});

// Provider cung cấp danh sách thẻ công khai (Stream)
final cardsStreamProvider = StreamProvider<List<CreditCard>>((ref) {
  return ref.watch(firestoreServiceProvider).getCards();
});

// Provider cung cấp thông tin chi tiết một thẻ (Future)
final cardDetailProvider = FutureProvider.family<CreditCard?, String>((ref, id) {
  return ref.watch(firestoreServiceProvider).getCardById(id);
});

// Provider cung cấp danh sách thẻ của user (Stream)
final userCardsStreamProvider = StreamProvider.autoDispose.family<List<UserCard>, String>((ref, userId) {
  final user = ref.watch(authStateProvider).value;
  if (user == null || user.uid != userId) {
    return const Stream.empty();
  }
  return ref.watch(firestoreServiceProvider).getUserCards(userId);
});

// Provider cung cấp danh sách ví của user (Stream)
final userWalletsStreamProvider = StreamProvider.autoDispose.family<List<UserWallet>, String>((ref, userId) {
  final user = ref.watch(authStateProvider).value;
  if (user == null || user.uid != userId) {
    return const Stream.empty();
  }
  return ref.watch(firestoreServiceProvider).getUserWallets(userId);
});

// Provider cung cấp danh sách giao dịch của user (Stream)
final transactionsStreamProvider = StreamProvider.autoDispose.family<List<Transaction>, String>((ref, userId) {
  final user = ref.watch(authStateProvider).value;
  if (user == null || user.uid != userId) {
    return const Stream.empty();
  }
  return ref.watch(firestoreServiceProvider).getTransactions(userId);
});

// Provider cung cấp danh sách thẻ mẫu (Mock) cho Home Screen khi user chưa có thẻ
final mockCardsProvider = Provider<List<CreditCard>>((ref) {
  final publicCards = ref.watch(cardsStreamProvider).value ?? [];
  if (publicCards.isEmpty) return [];

  final uniqueBankCards = <CreditCard>[];
  final seenBanks = <String>{};
  
  // Sort or shuffle but in a stable way if possible, or just shuffle
  final shuffledCards = publicCards.toList()..shuffle();

  for (var c in shuffledCards) {
    if (!seenBanks.contains(c.bankName) && c.imagePath.startsWith('http')) {
      uniqueBankCards.add(c);
      seenBanks.add(c.bankName);
      if (uniqueBankCards.length >= 3) break;
    }
  }

  if (uniqueBankCards.length < 3) {
    for (var c in shuffledCards) {
      if (!uniqueBankCards.contains(c)) {
        uniqueBankCards.add(c);
        if (uniqueBankCards.length >= 3) break;
      }
    }
  }
  return uniqueBankCards;
});
