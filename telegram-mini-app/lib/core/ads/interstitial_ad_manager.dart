import 'dart:developer';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'admob_config.dart';
import 'admob_store.dart';

/// Manages interstitial ads with smart display logic.
/// Shows ads between important screen navigations.
class InterstitialAdManager {
  InterstitialAd? _interstitialAd;
  bool _isLoading = false;
  int _numInterstitialLoadAttempts = 0;
  static const int maxFailedLoadAttempts = 3;
  
  // Navigation counter to avoid showing ads too frequently
  int _navigationCounter = 0;
  static const int navigationThreshold = 3; // Show ad every 3 navigations

  final AdmobStore _admobStore;

  InterstitialAdManager(this._admobStore);

  /// Loads an interstitial ad if not already loaded.
  Future<void> loadAd() async {
    if (kIsWeb || !AdmobStore.isEnabled) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (_isLoading || _interstitialAd != null) return;

    final adUnitId = _admobStore.resolveUnitId(
      adType: 'interstitial',
      debugFallback: Platform.isIOS
          ? AdMobConfig.testInterstitialIos
          : AdMobConfig.testInterstitialAndroid,
      releaseFallback: Platform.isIOS
          ? AdMobConfig.interstitialAdUnitIdIos
          : AdMobConfig.interstitialAdUnitIdAndroid,
    );

    _isLoading = true;

    await InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          log('InterstitialAd loaded');
          _interstitialAd = ad;
          _numInterstitialLoadAttempts = 0;
          _isLoading = false;

          _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              log('InterstitialAd showed full screen');
            },
            onAdDismissedFullScreenContent: (ad) {
              log('InterstitialAd dismissed');
              ad.dispose();
              _interstitialAd = null;
              // Preload next ad
              loadAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              log('InterstitialAd failed to show: $error');
              ad.dispose();
              _interstitialAd = null;
              loadAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          log('InterstitialAd failed to load: $error');
          _isLoading = false;
          _numInterstitialLoadAttempts += 1;
          _interstitialAd = null;

          if (_numInterstitialLoadAttempts < maxFailedLoadAttempts) {
            Future.delayed(
              Duration(seconds: _numInterstitialLoadAttempts * 2),
              loadAd,
            );
          }
        },
      ),
    );
  }

  /// Shows the ad if loaded and navigation threshold is met.
  /// Returns true if ad was shown.
  Future<bool> showAdIfReady() async {
    if (!AdmobStore.isEnabled) return false;
    
    _navigationCounter++;
    
    // Only show ad every N navigations
    if (_navigationCounter < navigationThreshold) {
      return false;
    }

    if (_interstitialAd != null) {
      _navigationCounter = 0; // Reset counter
      await _interstitialAd?.show();
      return true;
    } else {
      // Ad not ready, try to load for next time
      loadAd();
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}
