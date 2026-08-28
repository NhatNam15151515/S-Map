import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

/// Fallback / No-Op implementation for ISecureStorage in decoupled/testing environments
class NoOpSecureStorage implements ISecureStorage {
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

/// Fallback / No-Op implementation for ISharedPreferences
class NoOpSharedPreferences implements ISharedPreferences {
  bool _firstInstall = false;
  String? _themeMode;

  @override
  Future<bool> get1stInstall() async => _firstInstall;

  @override
  Future<void> save1stInstall() async => _firstInstall = false;

  @override
  Future<String?> getThemeMode() async => _themeMode;

  @override
  Future<void> saveThemeMode(String mode) async => _themeMode = mode;
}

/// Fallback / No-Op implementation for ILocalAuthService
class NoOpLocalAuthService implements ILocalAuthService {
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

/// Fallback / No-Op implementation for IFirebaseAnalyticsService
class NoOpAnalyticsService implements IFirebaseAnalyticsService {
  @override
  Future init() async {}

  @override
  Future logEvent(String name, Map<String, dynamic> params) async {}

  @override
  Future resetUserDetail({User? profile}) async {}
}
