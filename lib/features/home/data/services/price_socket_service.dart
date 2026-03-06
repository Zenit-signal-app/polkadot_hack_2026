import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/ohlcv_snapshot_model.dart';

class PriceSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  final StreamController<OhlcvSnapshotMessage> _snapshotController =
      StreamController<OhlcvSnapshotMessage>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  Stream<OhlcvSnapshotMessage> get snapshotStream => _snapshotController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  /// Derives the WebSocket URL from the API_BASE_URL env variable.
  /// e.g. https://zenit-api.seerbot.io/ → wss://zenit-api.seerbot.io/ohlcv
  static String get _defaultWsUrl {
    final base = dotenv.env['API_BASE_URL'] ?? 'https://zenit-api.seerbot.io/';
    final wsBase = base
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://')
        .replaceAll(RegExp(r'/+$'), '');
    return '$wsBase/ohlcv';
  }

  Future<void> connect({String? customUrl}) async {
    await disconnect();
    final url = customUrl ?? _defaultWsUrl;
    log('Connecting to WebSocket: $url');
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));

      // Await the real handshake — throws if the server refuses.
      await _channel!.ready;

      _isConnected = true;
      _connectionController.add(true);
      log('WebSocket connected: $url');

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: (Object error) {
          log('WebSocket error: $error');
          _isConnected = false;
          _connectionController.add(false);
        },
        onDone: () {
          log('WebSocket closed');
          _isConnected = false;
          _connectionController.add(false);
        },
      );
    } catch (e) {
      log('Error connecting to WebSocket: $e');
      _isConnected = false;
      _connectionController.add(false);
    }
  }

  void _onMessage(dynamic raw) {
    try {
      log('WS raw message (first 300 chars): ${raw.toString().substring(0, raw.toString().length.clamp(0, 300))}');
      final json = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = json['type'];
      final data = json['data'];
      final symbolKeys = data is Map ? data.keys.toList() : [];
      log('WS message type=$type totalSymbols=${symbolKeys.length} symbols=${symbolKeys.take(5)}');
      if (type == 'snapshot') {
        final msg = OhlcvSnapshotMessage.fromJson(json);
        log('WS snapshot parsed: ${msg.data.length} symbols');
        _snapshotController.add(msg);
      } else {
        log('WS unknown message type: $type');
      }
    } catch (e, st) {
      log('Error parsing WebSocket message: $e\n$st');
    }
  }

  // No-ops — server sends all tokens automatically; no subscribe messages needed.
  void subscribeToToken(String symbol) {}
  void unsubscribeFromToken(String symbol) {}
  void subscribeToMultipleTokens(List<String> symbols) {}

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _snapshotController.close();
    _connectionController.close();
  }
}

// Legacy stub — kept so existing imports do not break.
class BinanceSocketService {
  void dispose() {}
}
