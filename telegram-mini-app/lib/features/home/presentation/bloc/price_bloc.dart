import 'dart:async';
import 'dart:developer';

import 'package:bloc/bloc.dart';
import '../../../../core/store/token_store.dart';
import '../../data/models/token_model.dart';
import '../../data/models/token_list_item_model.dart';
import '../../data/models/ohlcv_snapshot_model.dart';
import '../../data/services/price_socket_service.dart';
import '../../data/services/token_service.dart';
import 'price_event.dart';
import 'price_state.dart';

class PriceBloc extends Bloc<PriceEvent, PriceState> {
  static const int _pageSize = 10;
  static const int _chartPointLimit = 24;
  static const String _chartTimeframe = '1h';
  static const int _chartCacheExpirySeconds = 2 * 60 * 60;
  static const int _maxChartCacheEntries = 200;
  final PriceSocketService _socketService;
  final TokenService _tokenService;
  final TokenStore _tokenStore;
  StreamSubscription? _priceSubscription;
  StreamSubscription? _connectionSubscription;
  final Set<String> _loadingChartSymbols = {};

  PriceBloc({
    PriceSocketService? socketService,
    TokenService? tokenService,
    required TokenStore tokenStore,
  })  : _tokenService = tokenService ?? TokenService(),
        _tokenStore = tokenStore,
        _socketService = socketService ?? PriceSocketService(),
        super(const PriceState()) {
    on<ConnectToPriceSocket>(_onConnectToPriceSocket);
    on<DisconnectFromPriceSocket>(_onDisconnectFromPriceSocket);
    on<SubscribeToToken>(_onSubscribeToToken);
    on<UnsubscribeFromToken>(_onUnsubscribeFromToken);
    on<SubscribeToMultipleTokens>(_onSubscribeToMultipleTokens);
    on<PriceUpdated>(_onPriceUpdated);
    on<AddToken>(_onAddToken);
    on<RemoveToken>(_onRemoveToken);
    on<LoadInitialTokens>(_onLoadInitialTokens);
    on<HydrateTokensFromStore>(_onHydrateTokensFromStore);
    on<LoadMoreTokens>(_onLoadMoreTokens);
    on<LoadTokenChartHistory>(_onLoadTokenChartHistory);
    on<ConnectionStatusChanged>(_onConnectionStatusChanged);
    on<OhlcvSnapshotReceived>(_onOhlcvSnapshotReceived);

    // Listen to OHLCV snapshots from the /ohlcv WebSocket
    _priceSubscription = _socketService.snapshotStream.listen((snapshot) {
      add(OhlcvSnapshotReceived(snapshot));
    });

    // Listen to connection status
    _connectionSubscription =
        _socketService.connectionStream.listen((isConnected) {
      add(ConnectionStatusChanged(isConnected));
    });
  }

  Future<void> _onConnectToPriceSocket(
    ConnectToPriceSocket event,
    Emitter<PriceState> emit,
  ) async {
    emit(state.copyWith(status: PriceStatus.loading));
    try {
      await _socketService.connect();
    } catch (e) {
      log('Error connecting to socket: $e');
      emit(state.copyWith(
        status: PriceStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onDisconnectFromPriceSocket(
    DisconnectFromPriceSocket event,
    Emitter<PriceState> emit,
  ) async {
    _socketService.disconnect();
    emit(state.copyWith(
      status: PriceStatus.disconnected,
      isConnected: false,
    ));
  }

  void _onSubscribeToToken(
    SubscribeToToken event,
    Emitter<PriceState> emit,
  ) {
    _socketService.subscribeToToken(event.symbol);
  }

  void _onUnsubscribeFromToken(
    UnsubscribeFromToken event,
    Emitter<PriceState> emit,
  ) {
    _socketService.unsubscribeFromToken(event.symbol);
  }

  void _onSubscribeToMultipleTokens(
    SubscribeToMultipleTokens event,
    Emitter<PriceState> emit,
  ) {
    _socketService.subscribeToMultipleTokens(event.symbols);
  }

  void _onPriceUpdated(
    PriceUpdated event,
    Emitter<PriceState> emit,
  ) {
    final currentToken = state.tokens[event.symbol];
    if (currentToken != null) {
      final updatedToken = currentToken.copyWith(
        currentPrice: event.price,
        priceChange: event.priceChange,
        priceChangePercentage: event.priceChangePercentage,
        lastUpdated: DateTime.now(),
      );

      final updatedTokens = Map<String, TokenModel>.from(state.tokens);
      updatedTokens[event.symbol] = updatedToken;

      emit(state.copyWith(tokens: updatedTokens));
    }
  }

  void _onAddToken(
    AddToken event,
    Emitter<PriceState> emit,
  ) {
    final updatedTokens = Map<String, TokenModel>.from(state.tokens);
    updatedTokens[event.token.symbol] = event.token;
    emit(state.copyWith(tokens: updatedTokens));
  }

  void _onRemoveToken(
    RemoveToken event,
    Emitter<PriceState> emit,
  ) {
    final updatedTokens = Map<String, TokenModel>.from(state.tokens);
    updatedTokens.remove(event.symbol);
    emit(state.copyWith(tokens: updatedTokens));
  }

  Future<void> _onLoadInitialTokens(
    LoadInitialTokens event,
    Emitter<PriceState> emit,
  ) async {
    emit(state.copyWith(status: PriceStatus.loading, errorMessage: null));
    try {
      final items = await _tokenService.getTokens(offset: 0, limit: _pageSize);
      _tokenStore.replaceAll(items, limit: _pageSize);

      final mapped = {
        for (final item in _tokenStore.state.items)
          item.symbol: _toTokenModel(
            item,
            chartHistoryCache: state.chartHistoryCache,
            chartHistoryLatestTimeCache: state.chartHistoryLatestTimeCache,
          ),
      };

      emit(state.copyWith(status: PriceStatus.initial, tokens: mapped));

      // Auto-connect socket once we have tokens.
      if (mapped.isNotEmpty && !_socketService.isConnected) {
        unawaited(_socketService.connect());
      }
    } catch (e) {
      log('LoadInitialTokens error: $e');
      emit(state.copyWith(
        status: PriceStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  void _onHydrateTokensFromStore(
    HydrateTokensFromStore event,
    Emitter<PriceState> emit,
  ) {
    final mapped = {
      for (final item in _tokenStore.state.items)
        item.symbol: _toTokenModel(
          item,
          chartHistoryCache: state.chartHistoryCache,
          chartHistoryLatestTimeCache: state.chartHistoryLatestTimeCache,
        ),
    };

    emit(state.copyWith(status: PriceStatus.initial, tokens: mapped));

    // Auto-connect socket once we have tokens.
    if (mapped.isNotEmpty && !_socketService.isConnected) {
      unawaited(_socketService.connect());
    }
  }

  Future<void> _onLoadMoreTokens(
    LoadMoreTokens event,
    Emitter<PriceState> emit,
  ) async {
    if (!_tokenStore.state.hasMore || state.status == PriceStatus.loading) {
      return;
    }

    emit(state.copyWith(status: PriceStatus.loading, errorMessage: null));
    try {
      final items = await _tokenService.getTokens(
        offset: _tokenStore.state.offset,
        limit: _tokenStore.state.limit,
      );
      _tokenStore.append(items);

      final mapped = {
        for (final item in _tokenStore.state.items)
          item.symbol: _toTokenModel(
            item,
            chartHistoryCache: state.chartHistoryCache,
            chartHistoryLatestTimeCache: state.chartHistoryLatestTimeCache,
          ),
      };

      emit(state.copyWith(status: PriceStatus.initial, tokens: mapped));
    } catch (e) {
      log('LoadMoreTokens error: $e');
      emit(state.copyWith(
        status: PriceStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadTokenChartHistory(
    LoadTokenChartHistory event,
    Emitter<PriceState> emit,
  ) async {
    final cacheKey = '${event.symbol}_${event.timeframe ?? _chartTimeframe}';
    if (_loadingChartSymbols.contains(cacheKey)) {
      return;
    }

    // Skip cache when custom timeframe is provided
    final useCustomTimeframe = event.timeframe != null;
    final cachedHistory = state.chartHistoryCache[event.symbol];
    final cachedLatestTime = state.chartHistoryLatestTimeCache[event.symbol];
    final isCacheFresh = !useCustomTimeframe &&
        cachedHistory != null &&
        cachedHistory.isNotEmpty &&
        cachedLatestTime != null &&
        !_isChartDataExpired(cachedLatestTime);

    if (isCacheFresh) {
      return;
    }

    final currentToken = state.tokens[event.symbol];
    if (currentToken == null) {
      return;
    }

    var nextChartCache = Map<String, List<double>>.from(state.chartHistoryCache);
    var nextLatestTimeCache =
        Map<String, int>.from(state.chartHistoryLatestTimeCache);
    if (cachedHistory != null || cachedLatestTime != null) {
      nextChartCache.remove(event.symbol);
      nextLatestTimeCache.remove(event.symbol);
      emit(state.copyWith(
        chartHistoryCache: nextChartCache,
        chartHistoryLatestTimeCache: nextLatestTimeCache,
      ));
    }

    _loadingChartSymbols.add(cacheKey);
    try {
      final historyResult = await _tokenService.getPriceHistory(
        symbol: event.symbol,
        timeframe: event.timeframe ?? _chartTimeframe,
        limit: event.limit ?? _chartPointLimit,
      );
      final chartData = historyResult.prices;
      final latestTime =
          _normalizeToSeconds(historyResult.latestTime ?? _currentEpochSeconds());

      final existingToken = state.tokens[event.symbol];
      if (existingToken == null) return;

      double priceChange = existingToken.priceChange;
      double priceChangePercentage = existingToken.priceChangePercentage;
      if (chartData.length >= 2) {
        final oldestPrice = chartData.first;
        final latestPrice = chartData.last;
        priceChange = latestPrice - oldestPrice;
        priceChangePercentage =
            oldestPrice == 0 ? 0 : (priceChange / oldestPrice) * 100;
      }

      final updatedTokens = Map<String, TokenModel>.from(state.tokens);
      updatedTokens[event.symbol] = existingToken.copyWith(
        chartData: chartData,
        priceChange: priceChange,
        priceChangePercentage: priceChangePercentage,
      );

      final updatedCache = Map<String, List<double>>.from(nextChartCache);
      updatedCache[event.symbol] = chartData;
      final updatedLatestTimeCache = Map<String, int>.from(nextLatestTimeCache);
      updatedLatestTimeCache[event.symbol] = latestTime;

      while (updatedCache.length > _maxChartCacheEntries) {
        final firstKey = updatedCache.keys.first;
        updatedCache.remove(firstKey);
        updatedLatestTimeCache.remove(firstKey);
      }

      emit(state.copyWith(
        tokens: updatedTokens,
        chartHistoryCache: updatedCache,
        chartHistoryLatestTimeCache: updatedLatestTimeCache,
      ));
    } catch (e) {
      log('LoadTokenChartHistory error for ${event.symbol}: $e');
    } finally {
      _loadingChartSymbols.remove(cacheKey);
    }
  }

  TokenModel _toTokenModel(
    TokenListItemModel item, {
    required Map<String, List<double>> chartHistoryCache,
    required Map<String, int> chartHistoryLatestTimeCache,
  }) {
    final millis = item.time > 1000000000000 ? item.time : item.time * 1000;
    final cachedChartData = chartHistoryCache[item.symbol] ?? const <double>[];
    final cachedLatestTime = chartHistoryLatestTimeCache[item.symbol];
    final hasFreshCache = cachedChartData.isNotEmpty &&
        cachedLatestTime != null &&
        !_isChartDataExpired(cachedLatestTime);
    final effectiveChartData = hasFreshCache ? cachedChartData : const <double>[];

    // Use API values if available, otherwise calculate from chart data
    double priceChange = item.priceChange;
    double priceChangePercentage = item.priceChangePercent;
    if (priceChange == 0 && priceChangePercentage == 0 && effectiveChartData.length >= 2) {
      final oldestPrice = effectiveChartData.first;
      final latestPrice = effectiveChartData.last;
      priceChange = latestPrice - oldestPrice;
      priceChangePercentage =
          oldestPrice == 0 ? 0 : (priceChange / oldestPrice) * 100;
    }

    return TokenModel(
      symbol: item.symbol,
      name: item.coin,
      pair: '${item.coin} / USD',
      imageUrl: item.image ?? '',
      currentPrice: item.price,
      decimals: item.decimals,
      priceChange: priceChange,
      priceChangePercentage: priceChangePercentage,
      chartData: effectiveChartData,
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(millis),
    );
  }

  bool _isChartDataExpired(int latestTimeEpoch) {
    final latestTime = _normalizeToSeconds(latestTimeEpoch);
    final delta = _currentEpochSeconds() - latestTime;
    return delta > _chartCacheExpirySeconds;
  }

  int _normalizeToSeconds(int epoch) {
    return epoch > 1000000000000 ? epoch ~/ 1000 : epoch;
  }

  int _currentEpochSeconds() {
    return DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }

  void _onConnectionStatusChanged(
    ConnectionStatusChanged event,
    Emitter<PriceState> emit,
  ) {
    emit(state.copyWith(
      isConnected: event.isConnected,
      status: event.isConnected ? PriceStatus.connected : PriceStatus.disconnected,
    ));
  }

  /// Bulk-updates token prices from a full OHLCV snapshot.
  /// Derives priceChange / priceChangePercentage from candle open→close
  /// (preference order: 1d > 4h > 1h > 30m > 5m > 1m).
  /// Uses Equatable equality on TokenModel to skip unchanged entries and
  /// avoid emitting a new state when nothing actually changed.
  void _onOhlcvSnapshotReceived(
    OhlcvSnapshotReceived event,
    Emitter<PriceState> emit,
  ) {
    log('[PriceBloc] snapshot received: ${event.snapshot.data.length} symbols, state has ${state.tokens.length} tokens');
    final updatedTokens = Map<String, TokenModel>.from(state.tokens);
    bool changed = false;
    int matched = 0;
    int skipped = 0;
    int noClose = 0;

    for (final entry in event.snapshot.data.entries) {
      final symbol = entry.key;
      final OhlcvSymbolData symbolData = entry.value;
      final currentToken = updatedTokens[symbol];
      if (currentToken == null) {
        skipped++;
        continue;
      }

      final closePrice = symbolData.closePrice;
      if (closePrice == null) {
        log('[PriceBloc] $symbol: closePrice is null, availableTFs=${symbolData.availableTimeframes}');
        noClose++;
        continue;
      }
      log('[PriceBloc] $symbol: closePrice=$closePrice tf=${symbolData.availableTimeframes} (was ${currentToken.currentPrice})');

      // Derive price change from the best available timeframe candle.
      double priceChange = currentToken.priceChange;
      double priceChangePercentage = currentToken.priceChangePercentage;
      final candles = symbolData.candles;
      if (candles != null) {
        const priority = ['1d', '4h', '1h', '30m', '5m', '1m'];
        for (final tf in priority) {
          final candle = candles[tf];
          if (candle != null && candle.open != 0) {
            priceChange = candle.close - candle.open;
            priceChangePercentage = (priceChange / candle.open) * 100;
            break;
          }
        }
      }

      final updated = currentToken.copyWith(
        currentPrice: closePrice,
        priceChange: priceChange,
        priceChangePercentage: priceChangePercentage,
        lastUpdated: DateTime.fromMillisecondsSinceEpoch(
          (symbolData.timestamp * 1000).toInt(),
        ),
      );

      // Skip if nothing changed (Equatable comparison).
      if (updated == currentToken) {
        log('[PriceBloc] $symbol: no change (Equatable equal), skipping');
        continue;
      }

      updatedTokens[symbol] = updated;
      changed = true;
      matched++;
    }

    log('[PriceBloc] snapshot done: matched=$matched noClose=$noClose skipped(notInState)=$skipped changed=$changed');
    if (changed) {
      emit(state.copyWith(tokens: updatedTokens));
    }
  }

  @override
  Future<void> close() {
    _priceSubscription?.cancel();
    _connectionSubscription?.cancel();
    _socketService.dispose();
    return super.close();
  }
}
