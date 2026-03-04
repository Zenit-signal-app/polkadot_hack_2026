import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/ai/data/models/chat_category_model.dart';
import '../../features/ai/data/models/chat_message_model.dart';
import '../../features/ai/data/repositories/chat_local_storage.dart';

class ChatState {
  const ChatState({
    this.categories = const [],
    this.activeCategoryIndex = 0,
    this.isLoaded = false,
  });

  final List<ChatCategory> categories;
  final int activeCategoryIndex;
  final bool isLoaded;

  ChatCategory? get activeCategory =>
      categories.isEmpty ? null : categories[activeCategoryIndex];

  /// Messages to display (reversed for ListView reverse: true)
  List<ChatMessage> get activeMessages =>
      activeCategory?.messages ?? [];

  ChatState copyWith({
    List<ChatCategory>? categories,
    int? activeCategoryIndex,
    bool? isLoaded,
  }) {
    return ChatState(
      categories: categories ?? this.categories,
      activeCategoryIndex: activeCategoryIndex ?? this.activeCategoryIndex,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

class ChatStore extends Cubit<ChatState> {
  ChatStore({ChatLocalStorage? localStorage})
      : _storage = localStorage ?? ChatLocalStorage(),
        super(const ChatState()) {
    _load();
  }

  final ChatLocalStorage _storage;

  Future<void> _load() async {
    final categories = await _storage.loadCategories();
    if (categories.isEmpty) {
      // Luôn có ít nhất 1 category mặc định
      final defaultCategory = ChatCategory(name: 'General');
      emit(state.copyWith(
        categories: [defaultCategory],
        activeCategoryIndex: 0,
        isLoaded: true,
      ));
      await _storage.saveCategories([defaultCategory]);
    } else {
      emit(state.copyWith(
        categories: categories,
        activeCategoryIndex: 0,
        isLoaded: true,
      ));
    }
  }

  /// Tạo category mới và chọn nó
  Future<void> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final newCategory = ChatCategory(name: trimmed);
    final updated = [...state.categories, newCategory];
    emit(state.copyWith(
      categories: updated,
      activeCategoryIndex: updated.length - 1,
    ));
    await _storage.saveCategories(updated);
  }

  /// Chuyển sang category theo index
  void selectCategory(int index) {
    if (index < 0 || index >= state.categories.length) return;
    emit(state.copyWith(activeCategoryIndex: index));
  }

  /// Thêm tin nhắn vào category đang active
  Future<void> addMessage(ChatMessage message) async {
    if (state.categories.isEmpty) return;

    final idx = state.activeCategoryIndex;
    final current = state.categories[idx];

    // Thêm message mới vào cuối
    final updatedMessages = [...current.messages, message];
    final updatedCategory = current.copyWith(messages: updatedMessages);

    // trimmedMessages tự cắt còn 4 user + 4 assistant khi save
    final updatedCategories = List<ChatCategory>.from(state.categories);
    updatedCategories[idx] = updatedCategory;

    emit(state.copyWith(categories: updatedCategories));
    // Lưu với trimmed (cắt bớt message cũ)
    await _storage.saveCategories(
      updatedCategories.map((c) {
        if (c == updatedCategory) {
          return c.copyWith(messages: c.trimmedMessages);
        }
        return c;
      }).toList(),
    );
  }

  /// Xóa tất cả tin nhắn trong category đang active
  Future<void> clearActiveCategory() async {
    if (state.categories.isEmpty) return;

    final idx = state.activeCategoryIndex;
    final current = state.categories[idx];
    final cleared = current.copyWith(messages: []);
    final updated = List<ChatCategory>.from(state.categories);
    updated[idx] = cleared;

    emit(state.copyWith(categories: updated));
    await _storage.saveCategories(updated);
  }

  /// Đổi tên category
  Future<void> renameCategory(int index, String newName) async {
    if (index < 0 || index >= state.categories.length) return;
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;

    final updated = List<ChatCategory>.from(state.categories);
    updated[index] = updated[index].copyWith(name: trimmed);
    emit(state.copyWith(categories: updated));
    await _storage.saveCategories(updated);
  }

  /// Xóa category
  Future<void> deleteCategory(int index) async {
    if (state.categories.length <= 1) return; // Luôn giữ ít nhất 1

    final updated = List<ChatCategory>.from(state.categories)
      ..removeAt(index);

    final newActiveIdx =
        (state.activeCategoryIndex >= updated.length)
            ? updated.length - 1
            : state.activeCategoryIndex;

    emit(state.copyWith(
      categories: updated,
      activeCategoryIndex: newActiveIdx,
    ));
    await _storage.saveCategories(updated);
  }

  Future<void> clearAll() async {
    final defaultCategory = ChatCategory(name: 'General');
    emit(state.copyWith(
      categories: [defaultCategory],
      activeCategoryIndex: 0,
    ));
    await _storage.clearAll();
    await _storage.saveCategories([defaultCategory]);
  }
}
