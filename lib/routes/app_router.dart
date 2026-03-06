import 'package:flutter/material.dart';

import 'app_routes.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/home/presentation/home_shell.dart';
import '../features/home/presentation/search_screen.dart';
import '../features/home/presentation/screens/token_info_screen.dart';
import '../features/home/data/models/token_model.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../features/analysis/presentation/screens/indicator_detail_screen.dart';
import '../features/analysis/data/models/indicator_model.dart';
import '../features/ai/presentation/screens/ai_chat_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
      case AppRoutes.login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );
      case AppRoutes.home:
        return MaterialPageRoute(
          builder: (_) => const HomeShell(initialIndex: 0),
          settings: settings,
        );
      case AppRoutes.analysis:
        return MaterialPageRoute(
          builder: (_) => const HomeShell(initialIndex: 1),
          settings: settings,
        );
      case AppRoutes.news:
        return MaterialPageRoute(
          builder: (_) => const HomeShell(initialIndex: 2),
          settings: settings,
        );
      case AppRoutes.chat:
        return MaterialPageRoute(
          builder: (_) => const HomeShell(initialIndex: 3),
          settings: settings,
        );
      case AppRoutes.aiChat:
        return MaterialPageRoute(
          builder: (_) => const AIChatScreen(),
          settings: settings,
        );
      case AppRoutes.search:
        return MaterialPageRoute(
          builder: (_) => const SearchScreen(),
          settings: settings,
        );
      case AppRoutes.tokenInfo:
        final token = settings.arguments as TokenModel?;
        if (token == null) {
          return MaterialPageRoute(
            builder: (_) => const HomeShell(initialIndex: 0),
            settings: settings,
          );
        }
        return MaterialPageRoute(
          builder: (_) => TokenInfoScreen(token: token),
          settings: settings,
        );
      case AppRoutes.notifications:
        return MaterialPageRoute(
          builder: (_) => const NotificationsScreen(),
          settings: settings,
        );
      case AppRoutes.indicatorDetail:
        final indicator = settings.arguments as IndicatorModel?;
        if (indicator == null) {
          return MaterialPageRoute(
            builder: (_) => const HomeShell(initialIndex: 1),
            settings: settings,
          );
        }
        return MaterialPageRoute(
          builder: (_) => IndicatorDetailScreen(indicator: indicator),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
    }
  }
}
