import 'package:equatable/equatable.dart';

class TokenListItemModel extends Equatable {
  final String symbol;
  final String coin;
  final double price;
  final int? decimals;
  final int time;
  final String timeReadable;
  final String? image;
  final double priceChange;
  final double priceChangePercent;
  final double volume;
  final double quoteVolume;

  const TokenListItemModel({
    required this.symbol,
    required this.coin,
    required this.price,
    this.decimals,
    required this.time,
    required this.timeReadable,
    this.image,
    this.priceChange = 0,
    this.priceChangePercent = 0,
    this.volume = 0,
    this.quoteVolume = 0,
  });

  factory TokenListItemModel.fromJson(Map<String, dynamic> json) {
    return TokenListItemModel(
      symbol: (json['symbol'] ?? '').toString(),
      coin: (json['coin'] ?? '').toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0,
      decimals: (json['decimals'] as num?)?.toInt(),
      time: (json['time'] as num?)?.toInt() ?? 0,
      timeReadable: (json['time_readable'] ?? '').toString(),
      image: json['image']?.toString(),
      priceChange: (json['priceChange'] as num?)?.toDouble() ?? 0,
      priceChangePercent: (json['priceChangePercent'] as num?)?.toDouble() ?? 0,
      volume: (json['volume'] as num?)?.toDouble() ?? 0,
      quoteVolume: (json['quoteVolume'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        symbol,
        coin,
        price,
        decimals,
        time,
        timeReadable,
        image,
        priceChange,
        priceChangePercent,
        volume,
        quoteVolume,
      ];
}
