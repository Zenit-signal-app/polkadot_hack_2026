class AdxRecord {
  final int openTime;
  final double? adx;
  final double? diPlus;
  final double? diMinus;
  final String? trend;

  const AdxRecord({
    required this.openTime,
    this.adx,
    this.diPlus,
    this.diMinus,
    this.trend,
  });

  factory AdxRecord.fromJson(Map<String, dynamic> json) {
    return AdxRecord(
      openTime: (json['open_time'] as num?)?.toInt() ?? 0,
      adx: (json['adx'] as num?)?.toDouble(),
      diPlus: (json['di_plus'] as num?)?.toDouble(),
      diMinus: (json['di_minus'] as num?)?.toDouble(),
      trend: json['trend']?.toString(),
    );
  }

  DateTime get dateTime =>
      DateTime.fromMillisecondsSinceEpoch(openTime * 1000);
}

class AdxResponse {
  final String symbol;
  final String timeframe;
  final List<AdxRecord> data;

  const AdxResponse({
    required this.symbol,
    required this.timeframe,
    required this.data,
  });

  factory AdxResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final records = rawData is List
        ? rawData
            .whereType<Map>()
            .map((e) => AdxRecord.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <AdxRecord>[];

    return AdxResponse(
      symbol: (json['symbol'] ?? '').toString(),
      timeframe: (json['timeframe'] ?? '').toString(),
      data: records,
    );
  }

  /// Chart-ready data lists. Records are newest-first, so we reverse them.
  List<double> get adxChartData =>
      data.reversed.map((r) => r.adx).whereType<double>().toList();

  List<double> get diPlusChartData =>
      data.reversed.map((r) => r.diPlus).whereType<double>().toList();

  List<double> get diMinusChartData =>
      data.reversed.map((r) => r.diMinus).whereType<double>().toList();
}
