import 'package:equatable/equatable.dart';

class TokenListItemModel extends Equatable {
  final String symbol;
  final String coin;
  final double price;
  final int? decimals;
  final int time;
  final String timeReadable;

  const TokenListItemModel({
    required this.symbol,
    required this.coin,
    required this.price,
    this.decimals,
    required this.time,
    required this.timeReadable,
  });

  factory TokenListItemModel.fromJson(Map<String, dynamic> json) {
    return TokenListItemModel(
      symbol: (json['symbol'] ?? '').toString(),
      coin: (json['coin'] ?? '').toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0,
      decimals: (json['decimals'] as num?)?.toInt(),
      time: (json['time'] as num?)?.toInt() ?? 0,
      timeReadable: (json['time_readable'] ?? '').toString(),
    );
  }

  @override
  List<Object?> get props => [symbol, coin, price, decimals, time, timeReadable];
}
