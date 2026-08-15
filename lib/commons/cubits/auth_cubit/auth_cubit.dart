import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:s_map/commons/cubits/auth_cubit/auth_state.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/repos/repos.dart';
import 'package:s_map/services/services.dart';
import 'package:flutter/foundation.dart';

class AuthCubit extends Cubit<AuthState> {
  final IAuthRepos _authRepos;
  final ValueNotifier<bool> faceIdAcceptStream = ValueNotifier(false);

  AuthCubit({IAuthRepos? authRepos})
      : _authRepos = authRepos ?? AuthReposImpl(),
        super(const InitialAuth()) {
    onAppStarted();
  }

  User get currentProfile {
    final curState = state;
    if (curState is Authenticated) {
      return curState.loggedInProfile;
    }
    return User.getInit(init: true);
  }

  @override
  void emit(AuthState state) {
    if (isClosed) return;
    super.emit(state);
  }

  Future<void> onAppStarted() async {
    // checkpoint to clear secure storage on 1st install
    if (await AppSharedPreferences().get1stInstall()) {
      await AppSecureStorage.onLogOutClear();
      await AppSharedPreferences().save1stInstall();
    }

    final authToken = await AppSecureStorage.getStoredAuthToken();
    final profile = await AppSecureStorage.getStoredProfile();

    if (authToken != null && profile != null) {
      final reqAuth = await AppSecureStorage.getReqAuth();
      faceIdAcceptStream.value = reqAuth;
      await onAuthenticated(profile);
    } else {
      emit(const UnAuthenticated());
    }
    FlutterNativeSplash.remove();
  }

  Future<void> onAuthenticated(User user) async {
    await AppSecureStorage.saveProfile(user);
    emit(Authenticated(user));
    await getAfterAuthStateEmitted();
  }

  Future<void> onLoggedIn(User user) async {
    faceIdAcceptStream.value = false;
    await onAuthenticated(user);
  }

  Future<void> updateProfile(User user) async {
    await AppSecureStorage.saveProfile(user);
    emit(Authenticated(user));
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
    final curState = state;
    if (curState is Authenticated) {
      final res = await FlutterLocalAuth.instance.authenticate();
      if (res) {
        await AppSecureStorage.saveReqAuth(accepted);
        faceIdAcceptStream.value = accepted;
      }
    }
  }

  Future<void> getAfterAuthStateEmitted() async {
    await FirebaseAnalyticsService().resetUserDetail(profile: currentProfile);
  }

  void onLogout({bool requestLogout = true}) async {
    emit(const UnAuthenticated());
    await AppSecureStorage.onLogOutClear();
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
