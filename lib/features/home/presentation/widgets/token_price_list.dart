import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../routes/app_routes.dart';
import '../../data/models/token_model.dart';
import '../bloc/price_bloc.dart';
import '../bloc/price_event.dart';
import '../bloc/price_state.dart';
import 'token_price_card.dart';

class TokenPriceList extends StatelessWidget {
  final PriceBloc priceBloc;
  final int selectedTabIndex;
  final Set<String> favoriteSymbols;
  final bool isFavoriteLoading;

  const TokenPriceList({
    super.key,
    required this.priceBloc,
    required this.selectedTabIndex,
    required this.favoriteSymbols,
    required this.isFavoriteLoading,
  });

  @override
  Widget build(BuildContext context) {
    return BlocSelector<PriceBloc, PriceState, _ListMeta>(
      bloc: priceBloc,
      selector: (state) => _ListMeta.from(
        state: state,
        selectedTabIndex: selectedTabIndex,
        favoriteSymbols: favoriteSymbols,
      ),
      builder: (context, meta) {
        if (meta.isError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              meta.errorMessage ?? 'Failed to load tokens',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }

        if (meta.isInitialLoading) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          );
        }

        if (selectedTabIndex == 1 && isFavoriteLoading) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          );
        }

        if (meta.symbols.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              selectedTabIndex == 1
                  ? 'No favorite tokens'
                  : 'No tokens available',
              style: const TextStyle(color: Colors.white70),
            ),
          );
        }

        // ── List ───────────────────────────────────────────────────────────
        final itemCount = meta.symbols.length + (meta.isLoadingMore ? 1 : 0);

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: itemCount,
          separatorBuilder: (_, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (meta.isLoadingMore && index == meta.symbols.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            return _TokenPriceItem(
              priceBloc: priceBloc,
              symbol: meta.symbols[index],
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-item widget: rebuilds only when its own TokenModel changes.
// TokenModel extends Equatable → BlocSelector skips rebuild when the value
// didn't change, so a BTCUSDT price tick never redraws ETHUSDT's card.
// ─────────────────────────────────────────────────────────────────────────────

class _TokenPriceItem extends StatelessWidget {
  final PriceBloc priceBloc;
  final String symbol;

  const _TokenPriceItem({required this.priceBloc, required this.symbol});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<PriceBloc, PriceState, TokenModel?>(
      bloc: priceBloc,
      selector: (state) => state.tokens[symbol],
      builder: (context, token) {
        if (token == null) return const SizedBox.shrink();
        return TokenPriceCard(
          token: token,
          onTap: () => Navigator.of(context).pushNamed(
            AppRoutes.tokenInfo,
            arguments: token,
          ),
          onVisible: () => priceBloc.add(LoadTokenChartHistory(symbol: symbol)),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Immutable snapshot of the state fields the list-level selector cares about.
// Custom == ensures BlocSelector correctly detects when a rebuild is needed.
// ─────────────────────────────────────────────────────────────────────────────

class _ListMeta {
  final bool isError;
  final String? errorMessage;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final List<String> symbols;

  const _ListMeta({
    required this.isError,
    this.errorMessage,
    required this.isInitialLoading,
    required this.isLoadingMore,
    required this.symbols,
  });

  factory _ListMeta.from({
    required PriceState state,
    required int selectedTabIndex,
    required Set<String> favoriteSymbols,
  }) {
    if (state.status == PriceStatus.error) {
      return _ListMeta(
        isError: true,
        errorMessage: state.errorMessage,
        isInitialLoading: false,
        isLoadingMore: false,
        symbols: const [],
      );
    }

    final isInitialLoading =
        state.status == PriceStatus.loading && state.tokenList.isEmpty;
    final isLoadingMore =
        state.status == PriceStatus.loading && state.tokenList.isNotEmpty;

    final symbols = selectedTabIndex == 1
        ? state.tokenList
              .where((t) => favoriteSymbols.contains(t.symbol))
              .map((t) => t.symbol)
              .toList()
        : state.tokenList.map((t) => t.symbol).toList();

    return _ListMeta(
      isError: false,
      isInitialLoading: isInitialLoading,
      isLoadingMore: isLoadingMore && selectedTabIndex == 0,
      symbols: symbols,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _ListMeta) {
      return false;
    }
    if (isError != other.isError ||
        errorMessage != other.errorMessage ||
        isInitialLoading != other.isInitialLoading ||
        isLoadingMore != other.isLoadingMore ||
        symbols.length != other.symbols.length) {
      return false;
    }
    for (int i = 0; i < symbols.length; i++) {
      if (symbols[i] != other.symbols[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    isError,
    errorMessage,
    isInitialLoading,
    isLoadingMore,
    Object.hashAll(symbols),
  );
}
