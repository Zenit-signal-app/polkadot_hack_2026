import 'package:equatable/equatable.dart';

class SignalNotificationModel extends Equatable {
  final String id;
  final String symbol;
  final String timeframe;
  final String message;
  final String createdAt;
  final String? image;

  const SignalNotificationModel({
    required this.id,
    required this.symbol,
    required this.timeframe,
    required this.message,
    required this.createdAt,
    this.image,
  });

  factory SignalNotificationModel.fromJson(Map<String, dynamic> json) {
    return SignalNotificationModel(
      id: (json['id'] ?? '').toString(),
      symbol: (json['symbol'] ?? '').toString(),
      timeframe: (json['timeframe'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      image: json['image']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'symbol': symbol,
      'timeframe': timeframe,
      'message': message,
      'created_at': createdAt,
      'image': image,
    };
  }

  @override
  List<Object?> get props => [
        id,
        symbol,
        timeframe,
        message,
        createdAt,
        image,
      ];
}
