import 'dart:developer';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'admob_config.dart';
import 'admob_store.dart';

/// Manages app open ads shown when app comes to foreground.
class AppOpenAdManager {
  AppOpenAd? _appOpenAd;
  bool _isShowingAd = false;
  bool _isLoading = false;
  DateTime? _appOpenLoadTime;
  
  // Maximum duration before ad is considered stale
  static const Duration maxCacheDuration = Duration(hours: 4);

  final AdmobStore _admobStore;

  AppOpenAdManager(this._admobStore);

  /// Loads an app open ad.
  Future<void> loadAd() async {
    if (kIsWeb || !AdmobStore.isEnabled) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (_isLoading || _appOpenAd != null) return;

    final adUnitId = _admobStore.resolveUnitId(
      adType: 'app_open',
      debugFallback: Platform.isIOS
          ? AdMobConfig.testAppOpenIos
          : AdMobConfig.testAppOpenAndroid,
      releaseFallback: Platform.isIOS
          ? AdMobConfig.appOpenAdUnitIdIos
          : AdMobConfig.appOpenAdUnitIdAndroid,
    );

    _isLoading = true;

    await AppOpenAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          log('AppOpenAd loaded');
          _appOpenAd = ad;
          _appOpenLoadTime = DateTime.now();
          _isLoading = false;

          _appOpenAd?.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              log('AppOpenAd showed full screen');
              _isShowingAd = true;
            },
            onAdDismissedFullScreenContent: (ad) {
              log('AppOpenAd dismissed');
              _isShowingAd = false;
              ad.dispose();
              _appOpenAd = null;
              // Preload next ad
              loadAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              log('AppOpenAd failed to show: $error');
              _isShowingAd = false;
              ad.dispose();
              _appOpenAd = null;
              loadAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          log('AppOpenAd failed to load: $error');
          _isLoading = false;
          _appOpenAd = null;
        },
      ),
    );
  }

  /// Shows the ad if loaded and not stale.
  Future<void> showAdIfAvailable() async {
    if (!AdmobStore.isEnabled) return;
    if (_isShowingAd) return;
    
    if (_appOpenAd == null) {
      log('AppOpenAd not loaded, loading now...');
      await loadAd();
      return;
    }

    // Check if ad is stale
    if (_appOpenLoadTime != null) {
      final Duration difference = DateTime.now().difference(_appOpenLoadTime!);
      if (difference > maxCacheDuration) {
        log('AppOpenAd is stale, disposing and loading new one');
        _appOpenAd?.dispose();
        _appOpenAd = null;
        await loadAd();
        return;
      }
    }

    await _appOpenAd?.show();
  }

  /// Dispose resources
  void dispose() {
    _appOpenAd?.dispose();
    _appOpenAd = null;
  }

  bool get isAdAvailable => _appOpenAd != null;
}
