import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    _loadFavorites();
    return {};
  }

  static const _key = 'favorite_cards';

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(_key) ?? [];
    state = favorites.toSet();
  }

  Future<void> toggleFavorite(String cardId) async {
    final prefs = await SharedPreferences.getInstance();
    final currentFavorites = Set<String>.from(state);
    
    if (currentFavorites.contains(cardId)) {
      currentFavorites.remove(cardId);
    } else {
      currentFavorites.add(cardId);
    }
    
    state = currentFavorites;
    await prefs.setStringList(_key, currentFavorites.toList());
  }

  bool isFavorite(String cardId) {
    return state.contains(cardId);
  }
}

final favoritesProvider = NotifierProvider<FavoritesNotifier, Set<String>>(() {
  return FavoritesNotifier();
});
