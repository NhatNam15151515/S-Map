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
        super(const AuthState()) {
    onAppStarted();
  }

  User get currentProfile {
    return state.loggedInProfile ?? User.getInit(init: true);
  }

  @override
  void emit(AuthState state) {
    if (isClosed) return;
    super.emit(state);
  }

  Future<void> onAppStarted() async {
    // checkpoint to clear secure storage on 1st install
    if (await _sharedPreferences.get1stInstall()) {
      await _secureStorage.onLogOutClear();
      await _sharedPreferences.save1stInstall();
    }

    final hasCompletedOnboarding = await _sharedPreferences
        .getOnboardingCompleted()
        .catchError((_) => false);

    final authToken = await _secureStorage.getStoredAuthToken();
    final profile = await _secureStorage.getStoredProfile();

    if (authToken != null && profile != null) {
      if (isClosed) return;
      final reqAuth = await _secureStorage.getReqAuth();
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
    FlutterNativeSplash.remove();
  }

  Future<void> onAuthenticated(User user) async {
    await _secureStorage.saveProfile(user);
    emit(state.copyWith(
      type: AuthStateType.authenticated,
      loggedInProfile: user,
    ));
    await getAfterAuthStateEmitted();
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
    emit(state.copyWith(type: AuthStateType.loading, clearError: true));
    try {
      final user = await _authRepos.signInWithGoogle();
      if (user != null) {
        await onLoggedIn(user);
        return true;
      } else {
        emit(state.copyWith(type: AuthStateType.unAuthenticated));
        return false;
      }
    } catch (e) {
      DLog.error('Lỗi đăng nhập Google: $e');
      emit(state.copyWith(
        type: AuthStateType.unAuthenticated,
        errorMessage: e.toString(),
      ));
      return false;
    }
  }

  Future<bool> signInAnonymously() async {
    emit(state.copyWith(type: AuthStateType.loading, clearError: true));
    try {
      final user = await _authRepos.signInAnonymously();
      if (user != null) {
        await onLoggedIn(user);
        return true;
      } else {
        emit(state.copyWith(type: AuthStateType.unAuthenticated));
        return false;
      }
    } catch (e) {
      DLog.error('Lỗi đăng nhập ẩn danh: $e');
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

  void onLogout({bool requestLogout = true}) async {
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
