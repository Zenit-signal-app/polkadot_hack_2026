import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/store/user_store.dart';
import '../data/auth_repository.dart';
import '../../../routes/app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthRepository _authRepository = AuthRepository();
  bool _isLoading = false;
  _AuthProvider? _loadingProvider;

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _loadingProvider = _AuthProvider.google;
    });

    try {
      final userInfo = await _authRepository.signInWithGoogle();
      if (!mounted) return;
      await context.read<UserStore>().setUserInfo(
        token: userInfo.token,
        refreshToken: userInfo.refreshToken,
        email: userInfo.email,
        displayName: userInfo.displayName,
        photoURL: userInfo.photoURL,
      );
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingProvider = null;
        });
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    if (_isLoading) return;
    final isApplePlatform = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    if (!isApplePlatform) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Apple sign-in is not supported here.')),
      );
      return;
    }
    setState(() {
      _isLoading = true;
      _loadingProvider = _AuthProvider.apple;
    });

    try {
      final userInfo = await _authRepository.signInWithApple();
      if (!mounted) return;
      await context.read<UserStore>().setUserInfo(
        token: userInfo.token,
        refreshToken: userInfo.refreshToken,
        email: userInfo.email,
        displayName: userInfo.displayName,
        photoURL: userInfo.photoURL,
      );
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Apple sign-in failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingProvider = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isApplePlatform = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final showGoogle = isAndroid || isApplePlatform;
    final showApple = isApplePlatform;

    return Scaffold(
      backgroundColor: AppColors.dark,
      body: SafeArea(
        child: Column(
          children: [
            const _LoginHeader(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Sign in to continue',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Access signals, insights, and updates across your devices.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.gray,
                          ),
                    ),
                    const SizedBox(height: 28),
                    if (showGoogle)
                      _AuthButton(
                        label: 'Continue with Google',
                        icon: HugeIcons.strokeRoundedGoogle,
                        background: AppColors.white,
                        foreground: AppColors.black,
                        isLoading: _loadingProvider == _AuthProvider.google,
                        isDisabled: _isLoading,
                        onPressed: _handleGoogleSignIn,
                      ),
                    if (showGoogle && showApple) const SizedBox(height: 14),
                    if (showApple)
                      _AuthButton(
                        label: 'Continue with Apple',
                        icon: HugeIcons.strokeRoundedApple,
                        background: AppColors.black,
                        foreground: AppColors.white,
                        isLoading: _loadingProvider == _AuthProvider.apple,
                        isDisabled: _isLoading,
                        onPressed: _handleAppleSignIn,
                      ),
                    const SizedBox(height: 18),
                    Text(
                      'By continuing you agree to our terms and privacy policy.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.gray,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AuthProvider { google, apple }

class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.dark, AppColors.darkBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
                return;
              }
              Navigator.of(context).pushReplacementNamed(AppRoutes.home);
            },
            icon: const Icon(Icons.arrow_back),
            color: AppColors.white,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 8),
          Text(
            'Zenit',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.isLoading,
    required this.isDisabled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final bool isLoading;
  final bool isDisabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: isDisabled ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.gray),
                ),
              )
            : Icon(icon, size: 20, color: foreground),
        label: Text(
          label,
          style: TextStyle(
            color: foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
