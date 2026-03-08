import 'package:flutter/widgets.dart';

import 'app_open_ad_manager.dart';

/// Listens to app lifecycle state changes and shows app open ads.
class AppLifecycleReactor extends WidgetsBindingObserver {
  final AppOpenAdManager _appOpenAdManager;
  var _lastPausedTime = DateTime.now();
  static const Duration _minPauseDuration = Duration(seconds: 3);

  AppLifecycleReactor(this._appOpenAdManager);

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        // Only show ad if app was paused for more than minimum duration
        final pauseDuration = DateTime.now().difference(_lastPausedTime);
        if (pauseDuration >= _minPauseDuration) {
          await _appOpenAdManager.showAdIfAvailable();
        }
        break;
      case AppLifecycleState.paused:
        _lastPausedTime = DateTime.now();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  void listenToAppStateChanges() {
    WidgetsBinding.instance.addObserver(this);
  }

  void stopListening() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
