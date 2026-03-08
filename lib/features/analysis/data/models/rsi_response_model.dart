/// Single item from `/signal-tools/rsi_heatmap/latest`
class RsiLatestItem {
  final String symbol;
  final String timeframe;
  final int openTime;
  final double? rsi7;
  final double? rsi14;
  final String image;

  const RsiLatestItem({
    required this.symbol,
    required this.timeframe,
    required this.openTime,
    this.rsi7,
    this.rsi14,
    required this.image,

  });

  factory RsiLatestItem.fromJson(Map<String, dynamic> json) {
    return RsiLatestItem(
      symbol: json['symbol']?.toString() ?? '',
      timeframe: json['timeframe']?.toString() ?? '',
      openTime: (json['open_time'] as num?)?.toInt() ?? 0,
      rsi7: (json['rsi7'] as num?)?.toDouble(),
      rsi14: (json['rsi14'] as num?)?.toDouble(),
      image: json['image']?.toString() ?? '',
    );
  }

  /// Short symbol without USDT suffix for display, e.g. "BTCUSDT" → "BTC".
  String get shortSymbol {
    const suffix = 'USDT';
    return symbol.endsWith(suffix)
        ? symbol.substring(0, symbol.length - suffix.length)
        : symbol;
  }
}

class RsiRecord {
  final int openTime;
  final double? rsi7;
  final double? rsi14;

  const RsiRecord({
    required this.openTime,
    this.rsi7,
    this.rsi14,
  });

  factory RsiRecord.fromJson(Map<String, dynamic> json) {
    return RsiRecord(
      openTime: (json['open_time'] as num?)?.toInt() ?? 0,
      rsi7: (json['rsi7'] as num?)?.toDouble(),
      rsi14: (json['rsi14'] as num?)?.toDouble(),
    );
  }

  DateTime get dateTime =>
      DateTime.fromMillisecondsSinceEpoch(openTime * 1000);
}

class RsiResponse {
  final String symbol;
  final String timeframe;
  final List<RsiRecord> data;

  const RsiResponse({
    required this.symbol,
    required this.timeframe,
    required this.data,
  });

  factory RsiResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final records = rawData is List
        ? rawData
            .whereType<Map>()
            .map((e) => RsiRecord.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <RsiRecord>[];

    return RsiResponse(
      symbol: (json['symbol'] ?? '').toString(),
      timeframe: (json['timeframe'] ?? '').toString(),
      data: records,
    );
  }

  /// Latest non-null rsi14 value (newest first from API).
  double? get latestRsi14 {
    for (final r in data) {
      if (r.rsi14 != null) return r.rsi14;
    }
    return null;
  }

  /// Latest non-null rsi7 value.
  double? get latestRsi7 {
    for (final r in data) {
      if (r.rsi7 != null) return r.rsi7;
    }
    return null;
  }

  /// RSI14 values in chronological order (oldest → newest) for line chart.
  List<double> get rsi14ChartData {
    return data.reversed
        .where((r) => r.rsi14 != null)
        .map((r) => r.rsi14!)
        .toList();
  }

  /// RSI7 values in chronological order (oldest → newest) for line chart.
  List<double> get rsi7ChartData {
    return data.reversed
        .where((r) => r.rsi7 != null)
        .map((r) => r.rsi7!)
        .toList();
  }
}
