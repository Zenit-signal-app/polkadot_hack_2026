import 'dart:developer';

import '../network/api_client.dart';
import 'admob_remote_config_model.dart';

class AdmobService {
  final ApiClient _apiClient;

  AdmobService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  void setAuthToken(String? token) {
    _apiClient.setAuthToken(token);
  }

  /// Calls `GET /admob/config` and returns the parsed remote config.
  Future<AdmobRemoteConfig> getConfig() async {
    try {
      final response = await _apiClient.get('admob/config');
      final Map<String, dynamic> json;
      if (response is Map<String, dynamic>) {
        json = response;
      } else if (response is Map) {
        json = Map<String, dynamic>.from(response);
      } else {
        log('AdmobService.getConfig unexpected format: $response');
        throw const FormatException('Unexpected admob/config response format');
      }
      return AdmobRemoteConfig.fromJson(json);
    } catch (e, st) {
      log('AdmobService.getConfig error: $e', stackTrace: st);
      rethrow;
    }
  }
}
