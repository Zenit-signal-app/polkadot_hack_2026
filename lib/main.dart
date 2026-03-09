import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'dart:io' show Platform;

import 'core/store/user_store.dart';
import 'core/store/token_store.dart';
import 'core/store/favorite_store.dart';
import 'core/store/chat_store.dart';
import 'core/store/chain_store.dart';
import 'core/ads/admob_store.dart';
import 'core/ads/ad_manager_store.dart';
import 'core/ads/app_lifecycle_reactor.dart';
import 'core/constants/app_colors.dart';
import 'core/services/notification_service.dart';
import 'routes/app_router.dart';
import 'routes/app_routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  
  // Skip Firebase initialization on web until firebase_options.dart is generated
  if (!kIsWeb) {
    await Firebase.initializeApp();

    // Register background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    
    // Initialize notification service
    await NotificationService().initialize();

    if (Platform.isIOS) {
      final status =
          await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    }

    await MobileAds.instance.initialize();
  }
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AdmobStore _admobStore;
  late final AdManagerStore _adManagerStore;

  @override
  void initState() {
    super.initState();
    _admobStore = AdmobStore();
    _adManagerStore = AdManagerStore(_admobStore);
  }

  @override
  void dispose() {
    _adManagerStore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zenit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.dark,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.white,
          secondary: AppColors.blue,
          surface: AppColors.darkBlue,
          onPrimary: AppColors.black,
          onSecondary: AppColors.white,
          onSurface: AppColors.white,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: AppColors.white),
          bodySmall: TextStyle(color: AppColors.gray),
          titleMedium: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      home: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _admobStore),
          BlocProvider(create: (_) => UserStore()),
          BlocProvider(create: (_) => TokenStore()),
          BlocProvider(create: (_) => FavoriteStore()),
          BlocProvider(create: (_) => ChatStore()),
          BlocProvider(create: (_) => ChainStore()),
        ],
        child: _AdManagerProvider(
          adManagerStore: _adManagerStore,
          child: _AppRoot(adManagerStore: _adManagerStore),
        ),
      ),
    );
  }
}

/// InheritedWidget to provide AdManagerStore to descendant widgets
class _AdManagerProvider extends InheritedWidget {
  final AdManagerStore adManagerStore;

  const _AdManagerProvider({
    required this.adManagerStore,
    required super.child,
  });

  static AdManagerStore of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<_AdManagerProvider>();
    assert(provider != null, 'No _AdManagerProvider found in context');
    return provider!.adManagerStore;
  }

  @override
  bool updateShouldNotify(_AdManagerProvider oldWidget) {
    return adManagerStore != oldWidget.adManagerStore;
  }
}

/// Helper function to get AdManagerStore from context
AdManagerStore getAdManagerStore(BuildContext context) {
  return _AdManagerProvider.of(context);
}

class _AppRoot extends StatefulWidget {
  final AdManagerStore adManagerStore;
  
  const _AppRoot({required this.adManagerStore});

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  AppLifecycleReactor? _appLifecycleReactor;

  @override
  void initState() {
    super.initState();
    _initializeAds();
  }

  Future<void> _initializeAds() async {
    final admobStore = context.read<AdmobStore>();
    await admobStore.load();
    
    // Initialize ad managers after config is loaded
    await widget.adManagerStore.initialize();
    
    // Set up app lifecycle observer for app open ads
    if (!kIsWeb && AdmobStore.isEnabled) {
      _appLifecycleReactor = AppLifecycleReactor(
        widget.adManagerStore.appOpenAdManager,
      );
      _appLifecycleReactor?.listenToAppStateChanges();
    }
  }

  @override
  void dispose() {
    _appLifecycleReactor?.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
