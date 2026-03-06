class PsarRecord {
  final int openTime;
  final double? psar;
  final String? psarType; // 'UP' | 'DOWN'
  final double? ep;
  final double? af;
  final int? psarTurn; // 1 if reversal, 0 otherwise

  const PsarRecord({
    required this.openTime,
    this.psar,
    this.psarType,
    this.ep,
    this.af,
    this.psarTurn,
  });

  factory PsarRecord.fromJson(Map<String, dynamic> json) {
    return PsarRecord(
      openTime: (json['open_time'] as num?)?.toInt() ?? 0,
      psar: (json['psar'] as num?)?.toDouble(),
      psarType: json['psar_type']?.toString(),
      ep: (json['ep'] as num?)?.toDouble(),
      af: (json['af'] as num?)?.toDouble(),
      psarTurn: (json['psar_turn'] as num?)?.toInt(),
    );
  }

  DateTime get dateTime =>
      DateTime.fromMillisecondsSinceEpoch(openTime * 1000);

  bool get isUp => psarType == 'UP';
  bool get isReversal => psarTurn == 1;
}

class PsarResponse {
  final String symbol;
  final String timeframe;
  final List<PsarRecord> data;

  const PsarResponse({
    required this.symbol,
    required this.timeframe,
    required this.data,
  });

  factory PsarResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final records = rawData is List
        ? rawData
            .whereType<Map>()
            .map((e) => PsarRecord.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <PsarRecord>[];

    return PsarResponse(
      symbol: (json['symbol'] ?? '').toString(),
      timeframe: (json['timeframe'] ?? '').toString(),
      data: records,
    );
  }

  /// Chart-ready data. Records are newest-first, so we reverse them.
  List<double> get psarChartData =>
      data.reversed.map((r) => r.psar).whereType<double>().toList();

  /// Reversal indices in chart order (oldest → newest).
  List<int> get reversalIndices {
    final reversed = data.reversed.toList();
    final indices = <int>[];
    for (var i = 0; i < reversed.length; i++) {
      if (reversed[i].isReversal) indices.add(i);
    }
    return indices;
  }
}
