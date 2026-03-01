import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io' show Platform;

import '../../../core/network/api_client.dart';
import '../../../core/auth/auth_local_storage.dart';

class UserAuthInfo {
  final String token;
  final String refreshToken;
  final String? email;
  final String? displayName;
  final String? photoURL;

  UserAuthInfo({
    required this.token,
    required this.refreshToken,
    this.email,
    this.displayName,
    this.photoURL,
  });
}

class AuthRepository {
  AuthRepository({
    FirebaseAuth? auth,
    ApiClient? apiClient,
    AuthLocalStorage? authLocalStorage,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _apiClient = apiClient ?? ApiClient(),
       _authLocalStorage = authLocalStorage ?? AuthLocalStorage();

  final FirebaseAuth _auth;
  final ApiClient _apiClient;
  final AuthLocalStorage _authLocalStorage;
  static Future<void>? _googleInit;
  final _googleSignIn = GoogleSignIn.instance;
  bool get _isApplePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<void> _ensureGoogleInitialized() {
    final serverClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
    if (serverClientId == null || serverClientId.isEmpty) {
      throw StateError('Missing GOOGLE_WEB_CLIENT_ID in .env');
    }

    // On iOS, also provide the iOS client ID for proper initialization
    final iosClientId = _isApplePlatform ? dotenv.env['GOOGLE_IOS_CLIENT_ID'] : null;

    return _googleInit ??= GoogleSignIn.instance.initialize(
      clientId: iosClientId,
      serverClientId: serverClientId,
    );
  }

  Future<UserAuthInfo> signInWithGoogle() async {
    await _ensureGoogleInitialized();
    GoogleSignInAccount googleUser;
    try {
      googleUser = await _googleSignIn.authenticate(scopeHint: ["email"]);
    } catch (e) {
      print(e);
      throw StateError('Google sign-in failed. Please try again. $e');
    }
    print(googleUser);

    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Missing Google ID token');
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);

    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;
    final token = await user?.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Unable to fetch token');
    }

    final exchanged = await _exchangeFirebaseLogin(
      firebaseIdToken: token,
      provider: 'google',
      user: user,
    );

    return UserAuthInfo(
      token: exchanged.accessToken,
      refreshToken: exchanged.refreshToken,
      email: exchanged.email ?? user?.email,
      displayName: exchanged.displayName ?? user?.displayName,
      photoURL: exchanged.photoURL ?? user?.photoURL,
    );
  }

  Future<void> _resetFirebaseSessionOnly() async {
    try {
      await _auth.signOut();
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  Future<UserAuthInfo> signInWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    if (credential.identityToken == null) {
      throw StateError('Missing identity token');
    }

    final oauthProvider = OAuthProvider('apple.com');
    final authCredential = oauthProvider.credential(
      idToken: credential.identityToken,
      accessToken: credential.authorizationCode,
    );

    final userCredential = await _auth.signInWithCredential(authCredential);
    final user = userCredential.user;
    final token = await user?.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Unable to fetch token');
    }

    final fallbackDisplayName =
        user?.displayName ??
        (credential.givenName != null && credential.familyName != null
            ? '${credential.givenName} ${credential.familyName}'
            : null);

    final exchanged = await _exchangeFirebaseLogin(
      firebaseIdToken: token,
      provider: 'apple',
      user: user,
      fallbackDisplayName: fallbackDisplayName,
    );

    return UserAuthInfo(
      token: exchanged.accessToken,
      refreshToken: exchanged.refreshToken,
      email: exchanged.email ?? user?.email,
      displayName: exchanged.displayName ?? fallbackDisplayName,
      photoURL: exchanged.photoURL ?? user?.photoURL,
    );
  }

  Future<void> signOut() async {
    final localSession = await _authLocalStorage.loadSession();
    final refreshToken = localSession.refreshToken;

    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        final response = await _apiClient.post(
          'auth/logout',
          body: {'refresh_token': refreshToken},
        );

        if (response is! Map<String, dynamic>) {
          throw const FormatException('Invalid logout response format');
        }

        final revoked = response['revoked'];
        if (revoked != true) {
          throw const FormatException('Refresh token revoke failed');
        }
      } catch (_) {
        // Continue local logout flow even when revoke call fails.
      }
    }

    if (!_isApplePlatform) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    await _auth.signOut();
    await _authLocalStorage.clearSession();
  }

  Future<_ExchangeResult> _exchangeFirebaseLogin({
    required String firebaseIdToken,
    required String provider,
    required User? user,
    String? fallbackDisplayName,
  }) async {
    final response = await _apiClient.post(
      'auth/firebase/login',
      body: {
        'firebase_id_token': firebaseIdToken,
        'id_token': firebaseIdToken,
        'provider': provider,
        'firebase_uid': user?.uid,
        'uid': user?.uid,
        'email': user?.email,
        'display_name': user?.displayName ?? fallbackDisplayName,
        'photo_url': user?.photoURL,
      },
    );

    if (response is! Map<String, dynamic>) {
      throw const FormatException('Invalid login response format');
    }

    final accessToken = _extractString(response, [
      'accessToken',
      'access_token',
    ]);
    final refreshToken = _extractString(response, [
      'refreshToken',
      'refresh_token',
    ]);

    if (accessToken == null || accessToken.isEmpty) {
      throw const FormatException('Missing access token from backend');
    }

    if (refreshToken == null || refreshToken.isEmpty) {
      throw const FormatException('Missing refresh token from backend');
    }

    return _ExchangeResult(
      accessToken: accessToken,
      refreshToken: refreshToken,
      email: _extractString(response, ['email']),
      displayName: _extractString(response, ['displayName', 'display_name']),
      photoURL: _extractString(response, ['photoURL', 'photo_url']),
    );
  }

  String? _extractString(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }

    final data = source['data'];
    if (data is Map<String, dynamic>) {
      for (final key in keys) {
        final value = data[key];
        if (value is String && value.isNotEmpty) {
          return value;
        }
      }
    }

    final tokens = source['tokens'];
    if (tokens is Map<String, dynamic>) {
      for (final key in keys) {
        final value = tokens[key];
        if (value is String && value.isNotEmpty) {
          return value;
        }
      }
    }

    final user = source['user'];
    if (user is Map<String, dynamic>) {
      for (final key in keys) {
        final value = user[key];
        if (value is String && value.isNotEmpty) {
          return value;
        }
      }
    }

    return null;
  }
}

class _ExchangeResult {
  const _ExchangeResult({
    required this.accessToken,
    required this.refreshToken,
    this.email,
    this.displayName,
    this.photoURL,
  });

  final String accessToken;
  final String refreshToken;
  final String? email;
  final String? displayName;
  final String? photoURL;
}
