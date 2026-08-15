import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:s_map/commons/cubits/auth_cubit/auth_state.dart';
import 'package:s_map/commons/enums/enums.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/repos/repos.dart';
import 'package:flutter/foundation.dart';

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
            secureStorage ?? defaultSecureStorage ?? _NoOpSecureStorage(),
        _sharedPreferences = sharedPreferences ??
            defaultSharedPreferences ??
            _NoOpSharedPreferences(),
        _localAuthService = localAuthService ??
            defaultLocalAuthService ??
            _NoOpLocalAuthService(),
        _analyticsService = analyticsService ??
            defaultAnalyticsService ??
            _NoOpAnalyticsService(),
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

    final authToken = await _secureStorage.getStoredAuthToken();
    final profile = await _secureStorage.getStoredProfile();

    if (authToken != null && profile != null) {
      final reqAuth = await _secureStorage.getReqAuth();
      faceIdAcceptStream.value = reqAuth;
      await onAuthenticated(profile);
    } else {
      if (state.isInitial) {
        emit(state.copyWith(type: AuthStateType.unAuthenticated));
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
    emit(state.copyWith(type: AuthStateType.loading));
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

// Private fallback implementations for test and decoupled environments

class _NoOpSecureStorage implements ISecureStorage {
  String? _token;
  User? _profile;
  bool _reqAuth = false;

  @override
  Future<String?> getStoredAuthToken() async => _token;

  @override
  Future<User?> getStoredProfile() async => _profile;

  @override
  Future<bool> getReqAuth() async => _reqAuth;

  @override
  Future<void> onLogOutClear() async {
    _token = null;
    _profile = null;
    _reqAuth = false;
  }

  @override
  Future<void> saveAuthToken(String token) async => _token = token;

  @override
  Future<void> saveProfile(User user) async => _profile = user;

  @override
  Future<void> saveReqAuth(bool value) async => _reqAuth = value;
}

class _NoOpSharedPreferences implements ISharedPreferences {
  bool _firstInstall = false;

  @override
  Future<bool> get1stInstall() async => _firstInstall;

  @override
  Future<void> save1stInstall() async => _firstInstall = false;
}

class _NoOpLocalAuthService implements ILocalAuthService {
  @override
  bool get faceIdAvailable => false;

  @override
  bool get initDone => true;

  @override
  Future<bool> authenticate() async => true;

  @override
  Future<void> getAvailableBio() async {}

  @override
  Future<void> init() async {}
}

class _NoOpAnalyticsService implements IFirebaseAnalyticsService {
  @override
  Future init() async {}

  @override
  Future logEvent(String name, Map<String, dynamic> params) async {}

  @override
  Future resetUserDetail({User? profile}) async {}
}
