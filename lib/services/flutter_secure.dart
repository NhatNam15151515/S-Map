import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s_map/interfaces/interfaces.dart';
import '../models/user.dart';

class AppSecureStorage implements ISecureStorage {
  static const FlutterSecureStorage repos = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  static const String appAccessToken = "appAccessToken";
  static const String loggedInProfile = "loggedInProfile";
  static const String requestLocalAuth = "requestLocalAuth";

  /// Singleton instance for use when injection is not available.
  static final AppSecureStorage instance = AppSecureStorage._();
  AppSecureStorage._();
  factory AppSecureStorage() => instance;

  @override
  Future<void> saveAuthToken(String token) async {
    await repos.write(key: appAccessToken, value: token);
  }

  @override
  Future<String?> getStoredAuthToken() async {
    final token = await repos.read(key: appAccessToken);
    return token;
  }

  @override
  Future<void> saveProfile(User user) async {
    await repos.write(key: loggedInProfile, value: jsonEncode(user.toJson()));
  }

  @override
  Future<User?> getStoredProfile() async {
    final rawProfile = await repos.read(key: loggedInProfile);
    if (rawProfile != null) {
      try {
        return User.fromJson(jsonDecode(rawProfile));
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<void> saveReqAuth(bool value) async {
    await repos.write(key: requestLocalAuth, value: value ? "1" : "0");
  }

  @override
  Future<bool> getReqAuth() async {
    final raw = await repos.read(key: requestLocalAuth);
    return raw == "1";
  }

  @override
  Future<void> onLogOutClear() {
    return Future.wait([
      repos.delete(key: appAccessToken),
      repos.delete(key: loggedInProfile),
      repos.delete(key: requestLocalAuth),
    ]);
  }
}

class AppSharedPreferences implements ISharedPreferences {
  late SharedPreferences prefs;
  Completer<bool> initComplete = Completer();
  static const String firstInstall = "first_install";
  static const String savedStore = "savedStore";

  static AppSharedPreferences? _instance;

  factory AppSharedPreferences() => _instance ??= AppSharedPreferences._();

  AppSharedPreferences._() {
    initial();
  }

  void initial() async {
    prefs = await SharedPreferences.getInstance();
    initComplete.complete(true);
  }

  static const String themeModeKey = "app_theme_mode";

  @override
  Future<bool> get1stInstall() async {
    await initComplete.future;
    return prefs.getBool(firstInstall) ?? true;
  }

  @override
  Future<void> save1stInstall() async {
    await initComplete.future;
    await prefs.setBool(firstInstall, false);
  }

  @override
  Future<String?> getThemeMode() async {
    await initComplete.future;
    return prefs.getString(themeModeKey);
  }

  @override
  Future<void> saveThemeMode(String mode) async {
    await initComplete.future;
    await prefs.setString(themeModeKey, mode);
  }
}
