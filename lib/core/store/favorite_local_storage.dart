import 'package:shared_preferences/shared_preferences.dart';

class FavoriteLocalStorage {
  static const _favoritesKey = 'favorites.symbols';

  Future<List<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_favoritesKey) ?? [];
  }

  Future<void> saveFavorites(List<String> symbols) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, symbols);
  }

  Future<void> addFavorite(String symbol) async {
    final favorites = await getFavorites();
    if (!favorites.contains(symbol)) {
      favorites.add(symbol);
      await saveFavorites(favorites);
    }
  }

  Future<void> removeFavorite(String symbol) async {
    final favorites = await getFavorites();
    favorites.remove(symbol);
    await saveFavorites(favorites);
  }

  Future<void> clearFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_favoritesKey);
  }
}
