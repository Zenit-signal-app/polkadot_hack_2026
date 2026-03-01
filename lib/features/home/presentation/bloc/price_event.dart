import 'package:equatable/equatable.dart';
import '../../data/models/token_model.dart';

abstract class PriceEvent extends Equatable {
  const PriceEvent();

  @override
  List<Object?> get props => [];
}

class ConnectToPriceSocket extends PriceEvent {
  const ConnectToPriceSocket();
}

class DisconnectFromPriceSocket extends PriceEvent {
  const DisconnectFromPriceSocket();
}

class SubscribeToToken extends PriceEvent {
  final String symbol;

  const SubscribeToToken(this.symbol);

  @override
  List<Object?> get props => [symbol];
}

class UnsubscribeFromToken extends PriceEvent {
  final String symbol;

  const UnsubscribeFromToken(this.symbol);

  @override
  List<Object?> get props => [symbol];
}

class SubscribeToMultipleTokens extends PriceEvent {
  final List<String> symbols;

  const SubscribeToMultipleTokens(this.symbols);

  @override
  List<Object?> get props => [symbols];
}

class PriceUpdated extends PriceEvent {
  final String symbol;
  final double price;
  final double priceChange;
  final double priceChangePercentage;

  const PriceUpdated({
    required this.symbol,
    required this.price,
    required this.priceChange,
    required this.priceChangePercentage,
  });

  @override
  List<Object?> get props => [symbol, price, priceChange, priceChangePercentage];
}

class AddToken extends PriceEvent {
  final TokenModel token;

  const AddToken(this.token);

  @override
  List<Object?> get props => [token];
}

class RemoveToken extends PriceEvent {
  final String symbol;

  const RemoveToken(this.symbol);

  @override
  List<Object?> get props => [symbol];
}

class LoadInitialTokens extends PriceEvent {
  const LoadInitialTokens();
}

class HydrateTokensFromStore extends PriceEvent {
  const HydrateTokensFromStore();
}

class LoadMoreTokens extends PriceEvent {
  const LoadMoreTokens();
}

class LoadTokenChartHistory extends PriceEvent {
  final String symbol;

  const LoadTokenChartHistory({required this.symbol});

  @override
  List<Object?> get props => [symbol];
}

class ConnectionStatusChanged extends PriceEvent {
  final bool isConnected;

  const ConnectionStatusChanged(this.isConnected);

  @override
  List<Object?> get props => [isConnected];
}
