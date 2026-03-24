import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesNotifier extends StateNotifier<Set<String>> {
  FavoritesNotifier() : super({}) {
    _loadFavorites();
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

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, Set<String>>((ref) {
  return FavoritesNotifier();
});
