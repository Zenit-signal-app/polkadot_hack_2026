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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Seerbot Signal',
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
          BlocProvider(create: (_) => UserStore()),
          BlocProvider(create: (_) => TokenStore()),
          BlocProvider(create: (_) => FavoriteStore()),
          BlocProvider(create: (_) => ChatStore()),
        ],
        child: const _AppRoot(),
      ),
    );
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    return Navigator(
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
