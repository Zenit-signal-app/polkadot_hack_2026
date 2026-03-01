import 'package:flutter_bloc/flutter_bloc.dart';

import '../auth/auth_local_storage.dart';

class UserState {
  const UserState({
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

  bool get isLoggedIn => accessToken != null && accessToken!.isNotEmpty;

  UserState copyWith({
    String? accessToken,
    String? refreshToken,
    String? email,
    String? displayName,
    String? photoURL,
  }) {
    return UserState(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
    );
  }
}

class UserStore extends Cubit<UserState> {
  UserStore({AuthLocalStorage? authLocalStorage})
      : _authLocalStorage = authLocalStorage ?? AuthLocalStorage(),
        super(const UserState()) {
    hydrateFromLocalStorage();
  }

  final AuthLocalStorage _authLocalStorage;

  Future<void> setAccessToken(String token) async {
    emit(state.copyWith(accessToken: token));
    await _authLocalStorage.updateTokens(
      accessToken: token,
      refreshToken: state.refreshToken,
    );
  }

  Future<void> setUserInfo({
    required String token,
    String? refreshToken,
    String? email,
    String? displayName,
    String? photoURL,
  }) async {
    final nextState = UserState(
      accessToken: token,
      refreshToken: refreshToken,
      email: email,
      displayName: displayName,
      photoURL: photoURL,
    );
    emit(nextState);

    await _authLocalStorage.saveSession(
      accessToken: token,
      refreshToken: refreshToken ?? '',
      email: email,
      displayName: displayName,
      photoURL: photoURL,
    );
  }

  Future<void> hydrateFromLocalStorage() async {
    final local = await _authLocalStorage.loadSession();
    final accessToken = local.accessToken;
    final refreshToken = local.refreshToken;

    if (accessToken == null || accessToken.isEmpty) {
      return;
    }

    emit(UserState(
      accessToken: accessToken,
      refreshToken: refreshToken,
      email: local.email,
      displayName: local.displayName,
      photoURL: local.photoURL,
    ));
  }

  Future<void> clearAccessToken() async {
    emit(const UserState());
    await _authLocalStorage.clearSession();
  }
}
