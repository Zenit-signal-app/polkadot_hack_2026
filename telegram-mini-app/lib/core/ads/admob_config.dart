/// Static fallback AdMob IDs.
/// Ad unit IDs are normally fetched from the remote `/admob/config` endpoint
/// via [AdmobStore]. These constants serve as fallbacks when the remote config
/// is not yet available.
class AdMobConfig {
  static const String publisherId = 'pub-1555215290851782';
  static const String adsenseClientId = '906-423-1734';

  static const String androidAppId =
      'ca-app-pub-1555215290851782~2557922401';
  static const String iosAppId = 'ca-app-pub-1555215290851782~4872406192';

  // Release fallbacks (used when remote config unavailable)
  static const String bannerAdUnitIdAndroid =
      'ca-app-pub-1555215290851782/7272502543';
  static const String bannerAdUnitIdIos =
      'ca-app-pub-1555215290851782/7464074238';
  static const String interstitialAdUnitIdAndroid =
      'ca-app-pub-1555215290851782/6865308437';
  static const String interstitialAdUnitIdIos =
      'ca-app-pub-1555215290851782/7579624304';
  static const String rewardedAdUnitIdAndroid =
      'ca-app-pub-1555215290851782/9299900084';
  static const String rewardedAdUnitIdIos =
      'ca-app-pub-1555215290851782/5910155697';
  static const String nativeAdUnitIdAndroid =
      'ca-app-pub-1555215290851782/2187221461';
  static const String nativeAdUnitIdIos =
      'ca-app-pub-1555215290851782/9491471771';
  static const String appOpenAdUnitIdAndroid =
      'ca-app-pub-1555215290851782/6074970944';
  static const String appOpenAdUnitIdIos =
      'ca-app-pub-1555215290851782/4813384802';

  // Google test IDs (debug mode only)
  static const String testBannerAndroid =
      'ca-app-pub-3940256099942544/6300978111';
  static const String testBannerIos =
      'ca-app-pub-3940256099942544/2934735716';
  static const String testInterstitialAndroid =
      'ca-app-pub-3940256099942544/1033173712';
  static const String testInterstitialIos =
      'ca-app-pub-3940256099942544/4411468910';
  static const String testRewardedAndroid =
      'ca-app-pub-3940256099942544/5224354917';
  static const String testRewardedIos =
      'ca-app-pub-3940256099942544/1712485313';
  static const String testNativeAndroid =
      'ca-app-pub-3940256099942544/2247696110';
  static const String testNativeIos =
      'ca-app-pub-3940256099942544/3986624511';
  static const String testAppOpenAndroid =
      'ca-app-pub-3940256099942544/9257395921';
  static const String testAppOpenIos =
      'ca-app-pub-3940256099942544/5575463023';
}
