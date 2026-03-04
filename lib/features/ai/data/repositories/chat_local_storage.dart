import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_category_model.dart';

class ChatLocalStorage {
  static const _categoriesKey = 'ai_chat.categories';

  Future<List<ChatCategory>> loadCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_categoriesKey);
      if (raw == null || raw.isEmpty) return [];

      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map((e) => ChatCategory.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCategories(List<ChatCategory> categories) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(categories.map((c) => c.toJson()).toList());
    await prefs.setString(_categoriesKey, encoded);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_categoriesKey);
  }
}
