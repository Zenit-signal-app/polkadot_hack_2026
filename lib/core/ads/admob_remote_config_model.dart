/// Platform-specific AdMob config (one instance for iOS, one for Android).
class AdmobPlatformConfig {
  final String id;
  final Map<String, String> adTypes;

  const AdmobPlatformConfig({required this.id, required this.adTypes});

  factory AdmobPlatformConfig.fromJson(Map<String, dynamic> json) {
    final rawAdTypes = json['ad_types'];
    final adTypes = <String, String>{};
    if (rawAdTypes is Map) {
      rawAdTypes.forEach((k, v) {
        if (k is String && v is String) adTypes[k] = v;
      });
    }
    return AdmobPlatformConfig(
      id: (json['id'] ?? '').toString(),
      adTypes: adTypes,
    );
  }

  /// Returns the ad unit ID for [adType], e.g. 'banner', 'interstitial',
  /// 'rewarded', 'rewarded_interstitial', 'native_advanced', 'app_open'.
  /// Returns null when the type is not in the remote config.
  String? unitId(String adType) => adTypes[adType];
}

class AdmobRemoteConfig {
  final AdmobPlatformConfig ios;
  final AdmobPlatformConfig android;

  const AdmobRemoteConfig({required this.ios, required this.android});

  factory AdmobRemoteConfig.fromJson(Map<String, dynamic> json) {
    return AdmobRemoteConfig(
      ios: AdmobPlatformConfig.fromJson(
          Map<String, dynamic>.from(json['ios'] as Map? ?? {})),
      android: AdmobPlatformConfig.fromJson(
          Map<String, dynamic>.from(json['android'] as Map? ?? {})),
    );
  }

  /// Returns the ad unit ID for [adType] on [platform] ('ios' | 'android').
  String? unitId(String platform, String adType) {
    return platform == 'ios' ? ios.unitId(adType) : android.unitId(adType);
  }
}
