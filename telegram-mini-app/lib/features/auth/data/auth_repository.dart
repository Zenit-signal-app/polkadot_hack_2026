import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

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

  Future<UserAuthInfo> signInWithGoogle() async {
    final googleProvider = GoogleAuthProvider();
    googleProvider.addScope('email');

    UserCredential userCredential;
    try {
      userCredential = await _auth.signInWithProvider(googleProvider);
    } catch (e) {
      print('Firebase Google sign-in error: $e');
      throw StateError('Google sign-in failed. Please try again. $e');
    }

    final user = userCredential.user;
    if (user == null) {
      throw StateError('Sign in failed: No user returned');
    }

    final refreshedUser = _auth.currentUser!;
    final token = await refreshedUser.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Unable to fetch token');
    }

    try {
      final exchanged = await _exchangeFirebaseLogin(
        firebaseIdToken: token,
        provider: 'google',
        user: refreshedUser,
      );

      return UserAuthInfo(
        token: exchanged.accessToken,
        refreshToken: exchanged.refreshToken,
        email: exchanged.email ?? refreshedUser.email,
        displayName: exchanged.displayName ?? refreshedUser.displayName,
        photoURL: exchanged.photoURL ?? refreshedUser.photoURL,
      );
    } on ApiException catch (e) {
      print('Backend login error: ${e.statusCode} - ${e.message}');
      throw StateError('Backend login failed: ${e.message}');
    } catch (e) {
      print('Exchange login error: $e');
      rethrow;
    }
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

    await _auth.signOut();
    await _authLocalStorage.clearSession();
  }

  Future<_ExchangeResult> _exchangeFirebaseLogin({
    required String firebaseIdToken,
    required String provider,
    required User user,
    String? fallbackDisplayName,
  }) async {
    final body = <String, dynamic>{'token': firebaseIdToken};

    final response = await _apiClient.post('auth/firebase/login', body: body);

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
