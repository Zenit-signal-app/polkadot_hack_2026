import 'package:equatable/equatable.dart';

class PriceUpdateModel extends Equatable {
  final String symbol;
  final double price;
  final double priceChange;
  final double priceChangePercentage;
  final DateTime timestamp;

  const PriceUpdateModel({
    required this.symbol,
    required this.price,
    required this.priceChange,
    required this.priceChangePercentage,
    required this.timestamp,
  });

  factory PriceUpdateModel.fromJson(Map<String, dynamic> json) {
    return PriceUpdateModel(
      symbol: json['symbol'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      priceChange: (json['priceChange'] ?? 0).toDouble(),
      priceChangePercentage: (json['priceChangePercentage'] ?? 0).toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'price': price,
      'priceChange': priceChange,
      'priceChangePercentage': priceChangePercentage,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        symbol,
        price,
        priceChange,
        priceChangePercentage,
        timestamp,
      ];
}
