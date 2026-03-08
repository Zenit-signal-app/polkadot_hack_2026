import 'dart:developer';

import '../../../../core/network/api_client.dart';
import '../models/signal_notification_model.dart';

class NotificationApiService {
  final ApiClient _apiClient;

  NotificationApiService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  void setAuthToken(String? token) {
    _apiClient.setAuthToken(token);
  }

  /// Get notifications with optional filtering and pagination
  /// 
  /// [symbol] - Optional filter by symbol (e.g. BTCUSDT)
  /// [timeframe] - Optional filter by timeframe (e.g. 1m, 5m, 1h, 4h, 1d, 1w)
  /// [limit] - Max number of records (1-200, default 50)
  /// [offset] - Number of records to skip (≥0, default 0)
  Future<List<SignalNotificationModel>> getNotifications({
    String? symbol,
    String? timeframe,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final safeOffset = offset < 0 ? 0 : offset;
      final safeLimit = limit.clamp(1, 200);

      final queryParams = <String, dynamic>{
        'limit': safeLimit,
        'offset': safeOffset,
      };

      // Only add symbol if it's provided and not empty
      if (symbol != null && symbol.trim().isNotEmpty) {
        queryParams['symbol'] = symbol.trim();
      }

      // Only add timeframe if it's provided and not empty
      if (timeframe != null && timeframe.trim().isNotEmpty) {
        queryParams['timeframe'] = timeframe.trim();
      }

      final response = await _apiClient.get(
        'notifications',
        queryParameters: queryParams,
      );

      final List<dynamic> notificationItems;
      if (response is List) {
        notificationItems = response;
      } else if (response is Map<String, dynamic> && response['data'] is List) {
        notificationItems = response['data'] as List<dynamic>;
      } else {
        log('NotificationApiService.getNotifications unexpected response format: $response');
        throw const FormatException('Unexpected notifications response format');
      }

      return notificationItems
          .whereType<Map>()
          .map((item) => SignalNotificationModel.fromJson(
              Map<String, dynamic>.from(item)))
          .toList();
    } catch (e, st) {
      log('NotificationApiService.getNotifications error: $e', stackTrace: st);
      rethrow;
    }
  }
}
