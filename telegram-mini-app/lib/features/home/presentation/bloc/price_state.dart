import 'package:equatable/equatable.dart';
import '../../data/models/token_model.dart';

enum PriceStatus { initial, loading, connected, disconnected, error }

class PriceState extends Equatable {
  final PriceStatus status;
  final Map<String, TokenModel> tokens;
  final Map<String, List<double>> chartHistoryCache;
  final Map<String, int> chartHistoryLatestTimeCache;
  final String? errorMessage;
  final bool isConnected;

  const PriceState({
    this.status = PriceStatus.initial,
    this.tokens = const {},
    this.chartHistoryCache = const {},
    this.chartHistoryLatestTimeCache = const {},
    this.errorMessage,
    this.isConnected = false,
  });

  PriceState copyWith({
    PriceStatus? status,
    Map<String, TokenModel>? tokens,
    Map<String, List<double>>? chartHistoryCache,
    Map<String, int>? chartHistoryLatestTimeCache,
    String? errorMessage,
    bool? isConnected,
  }) {
    return PriceState(
      status: status ?? this.status,
      tokens: tokens ?? this.tokens,
      chartHistoryCache: chartHistoryCache ?? this.chartHistoryCache,
      chartHistoryLatestTimeCache:
          chartHistoryLatestTimeCache ?? this.chartHistoryLatestTimeCache,
      errorMessage: errorMessage,
      isConnected: isConnected ?? this.isConnected,
    );
  }

  TokenModel? getToken(String symbol) => tokens[symbol];

  List<TokenModel> get tokenList => tokens.values.toList();

  @override
  List<Object?> get props => [
        status,
        tokens,
        chartHistoryCache,
        chartHistoryLatestTimeCache,
        errorMessage,
        isConnected,
      ];
}
