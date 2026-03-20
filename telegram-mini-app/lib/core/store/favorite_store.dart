import 'package:flutter_bloc/flutter_bloc.dart';

import 'favorite_local_storage.dart';

class FavoriteState {
  const FavoriteState({
    this.symbols,
    this.isLoading = false,
  });

  /// null = chưa load (chưa gọi API). [] = đã load nhưng không có favorites.
  final List<String>? symbols;
  final bool isLoading;

  /// true khi đã được sync từ API hoặc localStorage
  bool get isLoaded => symbols != null;

  bool isFavorite(String symbol) => symbols?.contains(symbol) ?? false;

  FavoriteState copyWith({
    List<String>? symbols,
    bool? isLoading,
  }) {
    return FavoriteState(
      symbols: symbols ?? this.symbols,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// Cho phép set symbols về null rõ ràng
  FavoriteState withSymbols(List<String>? symbols) {
    return FavoriteState(
      symbols: symbols,
      isLoading: isLoading,
    );
  }
}

class FavoriteStore extends Cubit<FavoriteState> {
  FavoriteStore({FavoriteLocalStorage? localStorage})
      : _localStorage = localStorage ?? FavoriteLocalStorage(),
        super(const FavoriteState());

  final FavoriteLocalStorage _localStorage;

  /// Check if a symbol is in favorites
  bool isFavorite(String symbol) => state.isFavorite(symbol);

  /// Add symbol to favorites (call after API success)
  Future<void> addFavorite(String symbol) async {
    final current = state.symbols ?? [];
    if (current.contains(symbol)) return;

    final updatedSymbols = [...current, symbol];
    emit(state.copyWith(symbols: updatedSymbols));
    await _localStorage.saveFavorites(updatedSymbols);
  }

  /// Remove symbol from favorites (call after API success)
  Future<void> removeFavorite(String symbol) async {
    final current = state.symbols ?? [];
    if (!current.contains(symbol)) return;

    final updatedSymbols = current.where((s) => s != symbol).toList();
    emit(state.copyWith(symbols: updatedSymbols));
    await _localStorage.saveFavorites(updatedSymbols);
  }

  /// Sync favorites từ API (bulk update, ghi vào localStorage)
  Future<void> syncFavorites(List<String> symbols) async {
    emit(state.copyWith(symbols: symbols));
    await _localStorage.saveFavorites(symbols);
  }

  /// Reset về null (chưa load)
  void reset() {
    emit(state.withSymbols(null));
  }

  /// Clear all favorites
  Future<void> clearFavorites() async {
    emit(state.copyWith(symbols: []));
    await _localStorage.clearFavorites();
  }
}
