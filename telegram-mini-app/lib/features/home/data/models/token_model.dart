import 'package:equatable/equatable.dart';

class TokenModel extends Equatable {
  final String symbol;
  final String name;
  final String pair;
  final String imageUrl;
  final double currentPrice;
  final int? decimals;
  final double priceChange;
  final double priceChangePercentage;
  final List<double> chartData;
  final DateTime lastUpdated;

  const TokenModel({
    required this.symbol,
    required this.name,
    required this.pair,
    required this.imageUrl,
    required this.currentPrice,
    this.decimals,
    required this.priceChange,
    required this.priceChangePercentage,
    required this.chartData,
    required this.lastUpdated,
  });

  factory TokenModel.fromJson(Map<String, dynamic> json) {
    return TokenModel(
      symbol: json['symbol'] ?? '',
      name: json['name'] ?? '',
      pair: json['pair'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      currentPrice: (json['currentPrice'] ?? 0).toDouble(),
      decimals: (json['decimals'] as num?)?.toInt(),
      priceChange: (json['priceChange'] ?? 0).toDouble(),
      priceChangePercentage: (json['priceChangePercentage'] ?? 0).toDouble(),
      chartData: (json['chartData'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'name': name,
      'pair': pair,
      'imageUrl': imageUrl,
      'currentPrice': currentPrice,
      'decimals': decimals,
      'priceChange': priceChange,
      'priceChangePercentage': priceChangePercentage,
      'chartData': chartData,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  TokenModel copyWith({
    String? symbol,
    String? name,
    String? pair,
    String? imageUrl,
    double? currentPrice,
    int? decimals,
    double? priceChange,
    double? priceChangePercentage,
    List<double>? chartData,
    DateTime? lastUpdated,
  }) {
    return TokenModel(
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      pair: pair ?? this.pair,
      imageUrl: imageUrl ?? this.imageUrl,
      currentPrice: currentPrice ?? this.currentPrice,
        decimals: decimals ?? this.decimals,
      priceChange: priceChange ?? this.priceChange,
      priceChangePercentage:
          priceChangePercentage ?? this.priceChangePercentage,
      chartData: chartData ?? this.chartData,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  bool get isPriceUp => priceChangePercentage > 0;

  @override
  List<Object?> get props => [
        symbol,
        name,
        pair,
        imageUrl,
        currentPrice,
        decimals,
        priceChange,
        priceChangePercentage,
        chartData,
        lastUpdated,
      ];
}
