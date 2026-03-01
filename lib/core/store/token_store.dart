import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/home/data/models/token_list_item_model.dart';

class TokenStoreState {
  const TokenStoreState({
    this.items = const [],
    this.offset = 0,
    this.limit = 10,
    this.hasMore = true,
  });

  final List<TokenListItemModel> items;
  final int offset;
  final int limit;
  final bool hasMore;

  TokenStoreState copyWith({
    List<TokenListItemModel>? items,
    int? offset,
    int? limit,
    bool? hasMore,
  }) {
    return TokenStoreState(
      items: items ?? this.items,
      offset: offset ?? this.offset,
      limit: limit ?? this.limit,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class TokenStore extends Cubit<TokenStoreState> {
  TokenStore() : super(const TokenStoreState());

  void replaceAll(List<TokenListItemModel> items, {int? limit}) {
    final resolvedLimit = limit ?? state.limit;
    emit(
      state.copyWith(
        items: items,
        offset: items.length,
        limit: resolvedLimit,
        hasMore: items.length >= resolvedLimit,
      ),
    );
  }

  void append(List<TokenListItemModel> items) {
    final merged = [...state.items, ...items];
    emit(
      state.copyWith(
        items: merged,
        offset: merged.length,
        hasMore: items.length >= state.limit,
      ),
    );
  }

  void clear() {
    emit(const TokenStoreState());
  }
}
