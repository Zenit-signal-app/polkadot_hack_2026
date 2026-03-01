import 'package:shared_preferences/shared_preferences.dart';

class AuthSessionData {
  const AuthSessionData({
    this.accessToken,
    this.refreshToken,
    this.email,
    this.displayName,
    this.photoURL,
  });

  final String? accessToken;
  final String? refreshToken;
  final String? email;
  final String? displayName;
  final String? photoURL;
}

class AuthLocalStorage {
  static const _accessTokenKey = 'auth.accessToken';
  static const _refreshTokenKey = 'auth.refreshToken';
  static const _emailKey = 'auth.email';
  static const _displayNameKey = 'auth.displayName';
  static const _photoUrlKey = 'auth.photoURL';

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    String? email,
    String? displayName,
    String? photoURL,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);

    if (email != null) {
      await prefs.setString(_emailKey, email);
    } else {
      await prefs.remove(_emailKey);
    }

    if (displayName != null) {
      await prefs.setString(_displayNameKey, displayName);
    } else {
      await prefs.remove(_displayNameKey);
    }

    if (photoURL != null) {
      await prefs.setString(_photoUrlKey, photoURL);
    } else {
      await prefs.remove(_photoUrlKey);
    }
  }

  Future<AuthSessionData> loadSession() async {
    final prefs = await SharedPreferences.getInstance();

    return AuthSessionData(
      accessToken: prefs.getString(_accessTokenKey),
      refreshToken: prefs.getString(_refreshTokenKey),
      email: prefs.getString(_emailKey),
      displayName: prefs.getString(_displayNameKey),
      photoURL: prefs.getString(_photoUrlKey),
    );
  }

  Future<void> updateTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await prefs.setString(_refreshTokenKey, refreshToken);
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_displayNameKey);
    await prefs.remove(_photoUrlKey);
  }
}
