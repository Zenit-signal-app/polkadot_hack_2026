import 'admob_store.dart';
import 'app_open_ad_manager.dart';
import 'interstitial_ad_manager.dart';

/// Central store for all ad managers
class AdManagerStore {
  late final InterstitialAdManager interstitialAdManager;
  late final AppOpenAdManager appOpenAdManager;

  AdManagerStore(AdmobStore admobStore) {
    interstitialAdManager = InterstitialAdManager(admobStore);
    appOpenAdManager = AppOpenAdManager(admobStore);
  }

  /// Initialize all ad managers
  Future<void> initialize() async {
    if (!AdmobStore.isEnabled) return;
    
    // Load initial ads
    await Future.wait([
      interstitialAdManager.loadAd(),
      appOpenAdManager.loadAd(),
    ]);
  }

  /// Dispose all resources
  void dispose() {
    interstitialAdManager.dispose();
    appOpenAdManager.dispose();
  }
}
