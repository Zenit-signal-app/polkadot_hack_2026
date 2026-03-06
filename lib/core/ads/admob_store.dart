import 'dart:developer';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../network/api_client.dart';
import 'admob_remote_config_model.dart';
import 'admob_service.dart';

class AdmobStore extends Cubit<AdmobRemoteConfig?> {
  AdmobStore() : super(null);

  /// Ads are only shown in release/profile builds to prevent Google blocking
  /// the AdMob account due to self-clicks or invalid traffic during development.
  static bool get isEnabled => !kDebugMode;

  /// Fetches the remote AdMob config and emits it.
  /// Safe to call multiple times — subsequent calls always refresh.
  Future<void> load({String? authToken}) async {
    try {
      final service = AdmobService(
        apiClient: ApiClient()..setAuthToken(authToken),
      );
      final config = await service.getConfig();
      emit(config);
    } catch (e) {
      log('AdmobStore.load failed: $e');
      // Keep whatever was previously loaded (or null); callers fall back to defaults.
    }
  }

  /// Returns the ad unit ID for [adType] on the current platform.
  ///
  /// Priority:
  ///   1. Remote config  (when loaded and available)
  ///   2. [debugFallback] (used only in debug mode when remote is absent)
  ///   3. [releaseFallback]
  String resolveUnitId({
    required String adType,
    String debugFallback = '',
    String releaseFallback = '',
  }) {
    if (!kIsWeb) {
      final platform = Platform.isIOS ? 'ios' : 'android';
      final remoteId = state?.unitId(platform, adType);
      if (remoteId != null && remoteId.isNotEmpty) {
        return remoteId;
      }
    }
    return kDebugMode ? debugFallback : releaseFallback;
  }
}
