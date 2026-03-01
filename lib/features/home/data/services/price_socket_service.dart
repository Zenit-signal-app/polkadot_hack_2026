import 'dart:async';
import 'dart:developer';

import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/price_update_model.dart';

class PriceSocketService {
  IO.Socket? _socket;
  final StreamController<PriceUpdateModel> _priceController =
      StreamController<PriceUpdateModel>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  Stream<PriceUpdateModel> get priceStream => _priceController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  bool get isConnected => _socket?.connected ?? false;

  // Default WebSocket URL - you can configure this in .env file
  static const String defaultSocketUrl = 'wss://stream.binance.com:9443/ws';

  Future<void> connect({String? customUrl}) async {
    try {
      final socketUrl = customUrl ?? defaultSocketUrl;
      
      // For Binance WebSocket, we don't use socket.io but pure WebSocket
      // This is a generic socket.io implementation
      // You can modify this based on your backend
      _socket = IO.io(
        socketUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            .setReconnectionAttempts(5)
            .build(),
      );

      _socket!.onConnect((_) {
        log('Socket connected');
        _connectionController.add(true);
      });

      _socket!.onDisconnect((_) {
        log('Socket disconnected');
        _connectionController.add(false);
      });

      _socket!.onConnectError((data) {
        log('Connection error: $data');
        _connectionController.add(false);
      });

      _socket!.onError((data) {
        log('Socket error: $data');
      });

      // Listen for price updates
      _socket!.on('price_update', (data) {
        try {
          final priceUpdate = PriceUpdateModel.fromJson(data);
          _priceController.add(priceUpdate);
        } catch (e) {
          log('Error parsing price update: $e');
        }
      });

      _socket!.connect();
    } catch (e) {
      log('Error connecting to socket: $e');
      _connectionController.add(false);
    }
  }

  void subscribeToToken(String symbol) {
    if (_socket?.connected == true) {
      _socket!.emit('subscribe', {'symbol': symbol});
      log('Subscribed to $symbol');
    }
  }

  void unsubscribeFromToken(String symbol) {
    if (_socket?.connected == true) {
      _socket!.emit('unsubscribe', {'symbol': symbol});
      log('Unsubscribed from $symbol');
    }
  }

  void subscribeToMultipleTokens(List<String> symbols) {
    if (_socket?.connected == true) {
      _socket!.emit('subscribe_multiple', {'symbols': symbols});
      log('Subscribed to ${symbols.length} tokens');
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _priceController.close();
    _connectionController.close();
  }
}

// Alternative implementation for Binance WebSocket (using raw WebSocket)
class BinanceSocketService {
  final StreamController<PriceUpdateModel> _priceController =
      StreamController<PriceUpdateModel>.broadcast();

  Stream<PriceUpdateModel> get priceStream => _priceController.stream;

  // Example: Subscribe to BTC/USDT ticker
  // wss://stream.binance.com:9443/ws/btcusdt@ticker
  void subscribeToBinanceTicker(String symbol) {
    // This would use dart:html WebSocket or web_socket_channel package
    // Implementation depends on your specific needs
    log('Subscribe to Binance ticker for $symbol');
  }

  void dispose() {
    _priceController.close();
  }
}
