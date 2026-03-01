import 'dart:developer';

import '../../../../core/network/api_client.dart';
import '../models/indicator_model.dart';

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
}
