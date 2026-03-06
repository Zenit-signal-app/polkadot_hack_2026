import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryStorage {
  static const _historyKey = 'search.history';
  static const int _maxHistoryItems = 10;

  Future<List<String>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_historyKey) ?? [];
  }

  Future<void> addToHistory(String keyword) async {
    if (keyword.trim().isEmpty) return;
    
    final history = await getHistory();
    // Remove if already exists (to move to top)
    history.remove(keyword);
    // Add to beginning
    history.insert(0, keyword);
    // Keep only max items
    if (history.length > _maxHistoryItems) {
      history.removeRange(_maxHistoryItems, history.length);
    }
    await _saveHistory(history);
  }

  Future<void> removeFromHistory(String keyword) async {
    final history = await getHistory();
    history.remove(keyword);
    await _saveHistory(history);
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  Future<void> _saveHistory(List<String> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, history);
  }
}
