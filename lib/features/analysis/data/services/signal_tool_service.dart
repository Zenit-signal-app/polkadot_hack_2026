import 'dart:developer';

import '../../../../core/network/api_client.dart';
import '../models/adx_response_model.dart';
import '../models/indicator_model.dart';
import '../models/psar_response_model.dart';
import '../models/rsi_response_model.dart';

class SignalToolService {
  final ApiClient _apiClient;

  SignalToolService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  void setAuthToken(String? token) {
    _apiClient.setAuthToken(token);
  }

  Future<List<IndicatorModel>> getSignalTools() async {
    try {
      final response = await _apiClient.get('signal-tools');

      final List<dynamic> toolItems;
      if (response is List) {
        toolItems = response;
      } else if (response is Map<String, dynamic> && response['data'] is List) {
        toolItems = response['data'] as List<dynamic>;
      } else {
        log('SignalToolService.getSignalTools unexpected response format: $response');
        throw const FormatException('Unexpected signal-tools response format');
      }

      final tools = toolItems
          .whereType<Map>()
          .map((item) => IndicatorModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      tools.sort((a, b) {
        final typeCompare = a.type.sortOrder.compareTo(b.type.sortOrder);
        if (typeCompare != 0) {
          return typeCompare;
        }
        return a.displayOrder.compareTo(b.displayOrder);
      });

      return tools;
    } catch (e, st) {
      log('SignalToolService.getSignalTools error: $e', stackTrace: st);
      rethrow;
    }
  }

  /// Calls `signal-tools/rsi_heatmap/latest` — returns latest RSI for all tokens.
  Future<List<RsiLatestItem>> getRsiLatestAll({
    String timeframe = '15m',
  }) async {
    try {
      final response = await _apiClient.get(
        'signal-tools/rsi_heatmap/latest',
        queryParameters: {'timeframe': timeframe},
      );

      final List<dynamic> items;
      if (response is List) {
        items = response;
      } else if (response is Map<String, dynamic> && response['data'] is List) {
        items = response['data'] as List<dynamic>;
      } else {
        log('SignalToolService.getRsiLatestAll unexpected format: $response');
        throw const FormatException('Unexpected rsi_heatmap/latest response format');
      }

      return items
          .whereType<Map>()
          .map((e) => RsiLatestItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e, st) {
      log('SignalToolService.getRsiLatestAll error: $e', stackTrace: st);
      rethrow;
    }
  }
  /// Returns an [RsiResponse] with rsi7/rsi14 records.
  Future<RsiResponse> getRsiData({
    required String code,
    required String symbol,
    String timeframe = '15m',
    int limit = 100,
  }) async {
    try {
      final response = await _apiClient.get(
        'signal-tools/$code',
        queryParameters: {
          'symbol': symbol,
          'timeframe': timeframe,
          'limit': limit,
        },
      );

      final Map<String, dynamic> json;
      if (response is Map<String, dynamic>) {
        json = response;
      } else if (response is Map) {
        json = Map<String, dynamic>.from(response);
      } else {
        log('SignalToolService.getRsiData unexpected format: $response');
        throw const FormatException('Unexpected signal-tools detail response format');
      }
      return RsiResponse.fromJson(json);
    } catch (e, st) {
      log('SignalToolService.getRsiData error: $e', stackTrace: st);
      rethrow;
    }
  }

  /// Calls `signal-tools/adx` — returns ADX + DI+/DI- records.
  Future<AdxResponse> getAdxData({
    required String symbol,
    String timeframe = '15m',
    int limit = 100,
  }) async {
    try {
      final response = await _apiClient.get(
        'signal-tools/adx',
        queryParameters: {
          'symbol': symbol,
          'timeframe': timeframe,
          'limit': limit,
        },
      );
      final Map<String, dynamic> json = response is Map<String, dynamic>
          ? response
          : Map<String, dynamic>.from(response as Map);
      return AdxResponse.fromJson(json);
    } catch (e, st) {
      log('SignalToolService.getAdxData error: $e', stackTrace: st);
      rethrow;
    }
  }

  /// Calls `signal-tools/psar` — returns Parabolic SAR records.
  Future<PsarResponse> getPsarData({
    required String symbol,
    String timeframe = '15m',
    int limit = 100,
  }) async {
    try {
      final response = await _apiClient.get(
        'signal-tools/psar',
        queryParameters: {
          'symbol': symbol,
          'timeframe': timeframe,
          'limit': limit,
        },
      );
      final Map<String, dynamic> json = response is Map<String, dynamic>
          ? response
          : Map<String, dynamic>.from(response as Map);
      return PsarResponse.fromJson(json);
    } catch (e, st) {
      log('SignalToolService.getPsarData error: $e', stackTrace: st);
      rethrow;
    }
  }
}
