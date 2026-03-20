import 'package:equatable/equatable.dart';

/// Single OHLCV candle from the /ohlcv WebSocket snapshot.
class OhlcvCandle extends Equatable {
  final int openTime;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  final double quoteAsset;
  final int numTrades;
  final double buyBase;
  final double buyQuote;

  const OhlcvCandle({
    required this.openTime,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.quoteAsset,
    required this.numTrades,
    required this.buyBase,
    required this.buyQuote,
  });

  factory OhlcvCandle.fromJson(Map<String, dynamic> json) {
    return OhlcvCandle(
      openTime: (json['open_time'] as num).toInt(),
      open: (json['open'] as num).toDouble(),
      high: (json['high'] as num).toDouble(),
      low: (json['low'] as num).toDouble(),
      close: (json['close'] as num).toDouble(),
      volume: (json['volume'] as num).toDouble(),
      quoteAsset: (json['quote_asset'] as num?)?.toDouble() ?? 0.0,
      numTrades: (json['num_trades'] as num?)?.toInt() ?? 0,
      buyBase: (json['buy_base'] as num?)?.toDouble() ?? 0.0,
      buyQuote: (json['buy_quote'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  List<Object?> get props =>
      [openTime, open, high, low, close, volume, quoteAsset, numTrades, buyBase, buyQuote];
}

/// Technical indicators for a single candle / timeframe.
class OhlcvIndicators extends Equatable {
  final int openTime;
  final double? tr;
  final double? rsi7;
  final double? rsi14;
  final double? atr14;
  final double? atr28;
  final double? dm14p;
  final double? dm14n;
  final double? di14p;
  final double? di14n;
  final double? dx14;
  final double? adx;
  final bool? di14LineCross;
  final double? psar;
  final String? psarType;
  final double? ep;
  final double? af;
  final bool? psarTurn;

  const OhlcvIndicators({
    required this.openTime,
    this.tr,
    this.rsi7,
    this.rsi14,
    this.atr14,
    this.atr28,
    this.dm14p,
    this.dm14n,
    this.di14p,
    this.di14n,
    this.dx14,
    this.adx,
    this.di14LineCross,
    this.psar,
    this.psarType,
    this.ep,
    this.af,
    this.psarTurn,
  });

  factory OhlcvIndicators.fromJson(Map<String, dynamic> json) {
    return OhlcvIndicators(
      openTime: (json['open_time'] as num).toInt(),
      tr: (json['tr'] as num?)?.toDouble(),
      rsi7: (json['rsi7'] as num?)?.toDouble(),
      rsi14: (json['rsi14'] as num?)?.toDouble(),
      atr14: (json['atr14'] as num?)?.toDouble(),
      atr28: (json['atr28'] as num?)?.toDouble(),
      dm14p: (json['dm14_p'] as num?)?.toDouble(),
      dm14n: (json['dm14_n'] as num?)?.toDouble(),
      di14p: (json['di14_p'] as num?)?.toDouble(),
      di14n: (json['di14_n'] as num?)?.toDouble(),
      dx14: (json['dx14'] as num?)?.toDouble(),
      adx: (json['adx'] as num?)?.toDouble(),
      di14LineCross: json['di14_line_cross'] as bool?,
      psar: (json['psar'] as num?)?.toDouble(),
      psarType: json['psar_type'] as String?,
      ep: (json['ep'] as num?)?.toDouble(),
      af: (json['af'] as num?)?.toDouble(),
      psarTurn: json['psar_turn'] as bool?,
    );
  }

  @override
  List<Object?> get props =>
      [openTime, tr, rsi7, rsi14, atr14, atr28, dm14p, dm14n, di14p, di14n, dx14, adx, di14LineCross, psar, psarType, ep, af, psarTurn];
}

/// Per-symbol data in the snapshot.
class OhlcvSymbolData extends Equatable {
  /// Server time (Unix seconds with ms precision).
  final double timestamp;

  /// Keyed by timeframe: "1m", "5m", "30m", "1h", "4h", "1d".
  final Map<String, OhlcvCandle>? candles;

  /// Keyed by timeframe.
  final Map<String, OhlcvIndicators>? indicators;

  const OhlcvSymbolData({
    required this.timestamp,
    this.candles,
    this.indicators,
  });

  /// Preferred close price: first available timeframe in priority order.
  /// Priority: lowest available timeframe = most recent price.
  double? get closePrice {
    if (candles == null || candles!.isEmpty) return null;
    const order = ['1m', '5m', '30m', '1h', '4h', '1d'];
    for (final tf in order) {
      final c = candles![tf];
      if (c != null && c.close > 0) return c.close;
    }
    // Fallback: return whatever is available
    return candles!.values.firstOrNull?.close;
  }

  /// Available timeframe keys for debugging.
  List<String> get availableTimeframes => candles?.keys.toList() ?? [];

  factory OhlcvSymbolData.fromJson(Map<String, dynamic> json) {
    Map<String, OhlcvCandle>? candles;
    final rawCandles = json['candles'] as Map<String, dynamic>?;
    if (rawCandles != null) {
      candles = rawCandles.map(
        (tf, v) => MapEntry(tf, OhlcvCandle.fromJson(v as Map<String, dynamic>)),
      );
    }

    Map<String, OhlcvIndicators>? indicators;
    final rawIndicators = json['indicators'] as Map<String, dynamic>?;
    if (rawIndicators != null) {
      indicators = rawIndicators.map(
        (tf, v) => MapEntry(tf, OhlcvIndicators.fromJson(v as Map<String, dynamic>)),
      );
    }

    return OhlcvSymbolData(
      timestamp: (json['timestamp'] as num).toDouble(),
      candles: candles,
      indicators: indicators,
    );
  }

  @override
  List<Object?> get props => [timestamp, candles, indicators];
}

/// Full snapshot message from the /ohlcv WebSocket endpoint.
/// Format: `{ "type": "snapshot", "data": { "SYMBOL": OhlcvSymbolData, ... } }`
class OhlcvSnapshotMessage extends Equatable {
  final String type;
  final Map<String, OhlcvSymbolData> data;

  const OhlcvSnapshotMessage({required this.type, required this.data});

  factory OhlcvSnapshotMessage.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'] as Map<String, dynamic>;
    final data = rawData.map(
      (symbol, v) => MapEntry(symbol, OhlcvSymbolData.fromJson(v as Map<String, dynamic>)),
    );
    return OhlcvSnapshotMessage(
      type: json['type'] as String,
      data: data,
    );
  }

  @override
  List<Object?> get props => [type, data];
}
