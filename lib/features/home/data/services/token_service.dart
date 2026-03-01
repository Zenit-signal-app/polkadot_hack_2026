import 'dart:developer';

import '../../../../core/network/api_client.dart';
import '../models/token_list_item_model.dart';

class TokenPriceHistoryResult {
  const TokenPriceHistoryResult({
    required this.prices,
    required this.latestTime,
  });

  final List<double> prices;
  final int? latestTime;
}

class TokenService {
  final ApiClient _apiClient;

  TokenService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  void setAuthToken(String? token) {
    _apiClient.setAuthToken(token);
  }

  Future<List<TokenListItemModel>> getTokens({
    int offset = 0,
    int limit = 100,
    String? key,
  }) async {
    try {
      final safeOffset = offset < 0 ? 0 : offset;
      final safeLimit = limit.clamp(1, 500);

      final response = await _apiClient.get(
        'tokens',
        queryParameters: {
          'offset': safeOffset,
          'limit': safeLimit,
          if (key != null && key.trim().isNotEmpty) 'key': key.trim(),
        },
      );

      final List<dynamic> tokenItems;
      if (response is List) {
        tokenItems = response;
      } else if (response is Map<String, dynamic> && response['data'] is List) {
        tokenItems = response['data'] as List<dynamic>;
      } else {
        log('TokenService.getTokens unexpected response format: $response');
        throw const FormatException('Unexpected token response format');
      }

      return tokenItems
          .map((item) => TokenListItemModel.fromJson(
              Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e, st) {
      log('TokenService.getTokens error: $e', stackTrace: st);
      rethrow;
    }
  }

  Future<TokenPriceHistoryResult> getPriceHistory({
    required String symbol,
    String timeframe = '1h',
    int limit = 24,
    int? fromTime,
    int? toTime,
  }) async {
    try {
      final safeLimit = limit.clamp(1, 1000);

      final response = await _apiClient.get(
        'prices/history',
        queryParameters: {
          'symbol': symbol,
          'timeframe': timeframe,
          'limit': safeLimit,
          if (fromTime != null) 'from_time': fromTime,
          if (toTime != null) 'to_time': toTime,
        },
      );

      final List<dynamic> historyItems;
      if (response is List) {
        historyItems = response;
      } else if (response is Map<String, dynamic> && response['data'] is List) {
        historyItems = response['data'] as List<dynamic>;
      } else {
        log('TokenService.getPriceHistory unexpected response format: $response');
        throw const FormatException('Unexpected price history response format');
      }

      final parsed = historyItems
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(
            (item) => (
              time: (item['time'] as num?)?.toInt() ?? 0,
              close: (item['close'] as num?)?.toDouble(),
            ),
          )
          .where((point) => point.close != null)
          .toList()
        ..sort((a, b) => a.time.compareTo(b.time));

      final prices = parsed.map((point) => point.close!).toList();
      final latestTime = parsed.isEmpty ? null : parsed.last.time;

      return TokenPriceHistoryResult(
        prices: prices,
        latestTime: latestTime,
      );
    } catch (e, st) {
      log('TokenService.getPriceHistory error: $e', stackTrace: st);
      rethrow;
    }
  }
}
