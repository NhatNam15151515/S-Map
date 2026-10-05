import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:s_map/commons/cubits/auth_cubit/auth_state.dart';
import 'package:s_map/commons/enums/enums.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/repos/repos.dart';
import 'package:flutter/foundation.dart';
import 'auth_fallbacks.dart';

class AuthCubit extends Cubit<AuthState> {
  final IAuthRepos _authRepos;
  final ISecureStorage _secureStorage;
  final ISharedPreferences _sharedPreferences;
  final ILocalAuthService _localAuthService;
  final IFirebaseAnalyticsService _analyticsService;
  final ValueNotifier<bool> faceIdAcceptStream = ValueNotifier(false);

  /// Global service resolvers set during app bootstrap
  static ISecureStorage? defaultSecureStorage;
  static ISharedPreferences? defaultSharedPreferences;
  static ILocalAuthService? defaultLocalAuthService;
  static IFirebaseAnalyticsService? defaultAnalyticsService;

  AuthCubit({
    IAuthRepos? authRepos,
    ISecureStorage? secureStorage,
    ISharedPreferences? sharedPreferences,
    ILocalAuthService? localAuthService,
    IFirebaseAnalyticsService? analyticsService,
  })  : _authRepos = authRepos ?? AuthReposImpl(),
        _secureStorage =
            secureStorage ?? defaultSecureStorage ?? NoOpSecureStorage(),
        _sharedPreferences = sharedPreferences ??
            defaultSharedPreferences ??
            NoOpSharedPreferences(),
        _localAuthService = localAuthService ??
            defaultLocalAuthService ??
            NoOpLocalAuthService(),
        _analyticsService = analyticsService ??
            defaultAnalyticsService ??
            NoOpAnalyticsService(),
        super(const AuthState());

  User get currentProfile {
    return state.loggedInProfile ?? User.getInit(init: true);
  }

  @override
  void emit(AuthState state) {
    if (isClosed) return;
    super.emit(state);
  }

  Future<void> onAppStarted() async {
    try {
      // 1. Checkpoint to clear secure storage on 1st install (fast timeout)
      try {
        final is1st = await _sharedPreferences
            .get1stInstall()
            .timeout(const Duration(milliseconds: 800), onTimeout: () => false);
        if (is1st) {
          await _secureStorage
              .onLogOutClear()
              .timeout(const Duration(milliseconds: 800));
          await _sharedPreferences.save1stInstall();
        }
      } catch (e) {
        DLog.warning('1st install checkpoint error: $e');
      }

      final hasCompletedOnboarding = await _sharedPreferences
          .getOnboardingCompleted()
          .timeout(const Duration(milliseconds: 800), onTimeout: () => false)
          .catchError((_) => false);

      if (isClosed) return;

      // 2. Đọc profile người dùng đã lưu từ SecureStorage với timeout ngắn
      User? profile;
      try {
        profile = await _secureStorage
            .getStoredProfile()
            .timeout(const Duration(milliseconds: 800), onTimeout: () => null);
      } catch (e) {
        DLog.warning('Error reading stored profile: $e');
      }
      if (isClosed) return;

      // 3. Nếu SecureStorage chưa có, kiểm tra phiên đăng nhập từ authRepos
      if (profile == null) {
        try {
          final fbProfile = await _authRepos
              .getProfile()
              .timeout(const Duration(seconds: 2), onTimeout: () => null);
          if (isClosed) return;
          if (fbProfile != null &&
              (fbProfile.id != null || fbProfile.username != null)) {
            profile = fbProfile;
          }
        } catch (e) {
          DLog.error('Lỗi khôi phục phiên người dùng: $e');
        }
      }

      if (profile != null) {
        if (isClosed) return;
        bool reqAuth = false;
        try {
          reqAuth = await _secureStorage
              .getReqAuth()
              .timeout(const Duration(milliseconds: 500), onTimeout: () => false);
        } catch (_) {}
        if (isClosed) return;
        faceIdAcceptStream.value = reqAuth;
        await onAuthenticated(profile);
      } else {
        if (isClosed) return;
        if (state.isInitial) {
          if (!hasCompletedOnboarding) {
            emit(state.copyWith(type: AuthStateType.onboarding));
          } else {
            emit(state.copyWith(type: AuthStateType.unAuthenticated));
          }
        }
      }
    } catch (e, stack) {
      DLog.error('onAppStarted error: $e', stack);
      if (isClosed) return;
      if (state.isInitial) {
        emit(state.copyWith(type: AuthStateType.onboarding));
      }
    } finally {
      try {
        FlutterNativeSplash.remove();
      } catch (_) {}
    }
  }

  Future<void> onAuthenticated(User user) async {
    final token = user.id ?? 'token_${DateTime.now().millisecondsSinceEpoch}';
    try {
      await _secureStorage
          .saveAuthToken(token)
          .timeout(const Duration(milliseconds: 800));
      await _secureStorage
          .saveProfile(user)
          .timeout(const Duration(milliseconds: 800));
    } catch (_) {}
    if (isClosed) return;
    emit(state.copyWith(
      type: AuthStateType.authenticated,
      loggedInProfile: user,
    ));
    try {
      await getAfterAuthStateEmitted().timeout(const Duration(milliseconds: 800));
    } catch (_) {}
  }

  Future<void> onLoggedIn(User user) async {
    faceIdAcceptStream.value = false;
    await onAuthenticated(user);
  }

  Future<void> completeOnboarding() async {
    await _sharedPreferences.saveOnboardingCompleted(true).catchError((_) {});
    if (isClosed) return;
    await loginGuest();
  }

  Future<void> loginGuest({String? username}) async {
    final user = User(username: username);
    await onLoggedIn(user);
  }

  Future<void> loginWithCredentials({
    required String username,
    required String password,
  }) async {
    final user = User(username: username);
    await onLoggedIn(user);
  }

  Future<bool> signInWithGoogle() async {
    if (isClosed) return false;
    emit(state.copyWith(type: AuthStateType.loading, clearError: true));
    try {
      final user = await _authRepos.signInWithGoogle();
      if (isClosed) return false;
      if (user != null) {
        await onLoggedIn(user);
        return true;
      } else {
        emit(state.copyWith(type: AuthStateType.unAuthenticated));
        return false;
      }
    } catch (e) {
      DLog.error('Lỗi đăng nhập Google: $e');
      if (isClosed) return false;
      emit(state.copyWith(
        type: AuthStateType.unAuthenticated,
        errorMessage: e.toString(),
      ));
      return false;
    }
  }

  Future<bool> signInAnonymously() async {
    if (isClosed) return false;
    emit(state.copyWith(type: AuthStateType.loading, clearError: true));
    try {
      final user = await _authRepos.signInAnonymously();
      if (isClosed) return false;
      if (user != null) {
        await onLoggedIn(user);
        return true;
      } else {
        emit(state.copyWith(type: AuthStateType.unAuthenticated));
        return false;
      }
    } catch (e) {
      DLog.error('Lỗi đăng nhập ẩn danh: $e');
      if (isClosed) return false;
      emit(state.copyWith(
        type: AuthStateType.unAuthenticated,
        errorMessage: e.toString(),
      ));
      return false;
    }
  }

  Future<void> updateProfile(User user) async {
    await _secureStorage.saveProfile(user);
    emit(state.copyWith(
      type: AuthStateType.authenticated,
      loggedInProfile: user,
    ));
  }

  Future<void> getProfile() async {
    try {
      final profile = await _authRepos.getProfile();
      if (profile != null) {
        await updateProfile(profile);
      }
    } on Exception catch (e) {
      DLog.error('Lỗi tải thông tin cá nhân: $e');
    }
  }

  void toggleAuthWithFaceId(bool accepted) async {
    if (state.isAuthenticated) {
      final res = await _localAuthService.authenticate();
      if (res) {
        await _secureStorage.saveReqAuth(accepted);
        faceIdAcceptStream.value = accepted;
      }
    }
  }

  Future<void> getAfterAuthStateEmitted() async {
    await _analyticsService.resetUserDetail(profile: currentProfile);
  }

  Future<void> onLogout({bool requestLogout = true}) async {
    emit(const AuthState(type: AuthStateType.unAuthenticated));
    await _secureStorage.onLogOutClear();
    if (requestLogout) await _requestLogout();
  }

  Future<void> _requestLogout() async {
    try {
      await _authRepos.logout();
    } on Exception catch (e) {
      DLog.error('Lỗi đăng xuất: $e');
    }
  }
}
