import 'package:flutter/material.dart';

import '../ads/admob_store.dart';
import '../../main.dart' show getAdManagerStore;

/// Helper class to show interstitial ads before navigation
class AdNavigationHelper {
  /// Shows interstitial ad before navigating if conditions are met.
  /// Returns Future<void> to allow awaiting ad display.
  static Future<void> navigateWithAd(
    BuildContext context, {
    required String routeName,
    Object? arguments,
  }) async {
    if (!AdmobStore.isEnabled) {
      // Ads disabled, navigate immediately
      Navigator.of(context).pushNamed(routeName, arguments: arguments);
      return;
    }

    try {
      // Try to get AdManagerStore from context
      final adManagerStore = getAdManagerStore(context);
      
      // Show ad if available (will check navigation threshold internally)
      final adShown = await adManagerStore.interstitialAdManager.showAdIfReady();
      
      if (adShown) {
        // Wait a bit after ad is dismissed before navigating
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } catch (e) {
      // AdManagerStore not available, just navigate
    }

    // Navigate to the target screen
    if (context.mounted) {
      Navigator.of(context).pushNamed(routeName, arguments: arguments);
    }
  }

  /// Shows ad before popping if needed
  static Future<void> popWithAd(BuildContext context) async {
    if (!AdmobStore.isEnabled) {
      Navigator.of(context).pop();
      return;
    }

    try {
      final adManagerStore = getAdManagerStore(context);
      await adManagerStore.interstitialAdManager.showAdIfReady();
    } catch (e) {
      // Ignore
    }

    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }
}
