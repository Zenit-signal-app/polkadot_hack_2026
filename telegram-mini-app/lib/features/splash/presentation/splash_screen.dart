import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/store/token_store.dart';
import '../../../core/store/user_store.dart';
import '../../home/data/services/token_service.dart';
import '../../../routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Request ATT after the app UI is visible (Apple requirement)
      if (!kIsWeb && Platform.isIOS) {
        try {
          final status =
              await AppTrackingTransparency.trackingAuthorizationStatus;
          if (status == TrackingStatus.notDetermined) {
            await AppTrackingTransparency.requestTrackingAuthorization();
          }
        } catch (_) {}
      }

      await Future.wait([
        _loadUserData(),
        _loadAppConfig(),
        _loadInitialData(),
      ]);

      // Ensure splash is shown for at least 2 seconds for better UX
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      }
    } catch (e) {
      // Handle error - you can show an error dialog or retry
      if (mounted) {
        // Still navigate to home even if there's an error
        // You can customize this behavior
        await Future.delayed(const Duration(milliseconds: 500));
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      }
    }
  }

  // Simulate API calls - replace these with your actual API calls
  Future<void> _loadUserData() async {
    await context.read<UserStore>().hydrateFromLocalStorage();
  }

  Future<void> _loadAppConfig() async {
    await Future.delayed(const Duration(milliseconds: 600));
  }

  Future<void> _loadInitialData() async {
    final apiClient = ApiClient()
      ..setAuthToken(context.read<UserStore>().state.accessToken);
    final tokenService = TokenService(apiClient: apiClient);
    final tokenStore = context.read<TokenStore>();

    final items = await tokenService.getTokens(offset: 0, limit: 10);
    tokenStore.replaceAll(items, limit: 10);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blue,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.dark,
              AppColors.darkBlue,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Logo Section
              _buildLogo(),
              const Spacer(),
              // Loading Spinner
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.blue),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/images/logo-app.png',
      width: 200,
      height: 200,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // Fallback nếu không load được logo
        return Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.darkBlue.withOpacity(0.3),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.blue.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.scatter_plot_rounded,
            size: 64,
            color: const Color.fromRGBO(16, 153, 251, 1),
          ),
        );
      },
    );
  }
}
