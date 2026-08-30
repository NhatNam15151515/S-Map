import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/interfaces.dart';
import '../models/user.dart';

class AppSecureStorage implements ISecureStorage {
  static const FlutterSecureStorage repos = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
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
    try {
      await repos.write(key: appAccessToken, value: token);
    } catch (e) {
      DLog.error("AppSecureStorage saveAuthToken error: $e");
    }
  }

  @override
  Future<String?> getStoredAuthToken() async {
    try {
      final token = await repos.read(key: appAccessToken);
      return token;
    } catch (e) {
      DLog.error("AppSecureStorage getStoredAuthToken error: $e");
      return null;
    }
  }

  @override
  Future<void> saveProfile(User user) async {
    try {
      await repos.write(key: loggedInProfile, value: jsonEncode(user.toJson()));
    } catch (e) {
      DLog.error("AppSecureStorage saveProfile error: $e");
    }
  }

  @override
  Future<User?> getStoredProfile() async {
    try {
      final rawProfile = await repos.read(key: loggedInProfile);
      if (rawProfile != null && rawProfile.isNotEmpty) {
        return User.fromJson(jsonDecode(rawProfile));
      }
    } catch (e) {
      DLog.error("AppSecureStorage getStoredProfile error: $e");
    }
    return null;
  }

  @override
  Future<void> saveReqAuth(bool value) async {
    try {
      await repos.write(key: requestLocalAuth, value: value ? "1" : "0");
    } catch (e) {
      DLog.error("AppSecureStorage saveReqAuth error: $e");
    }
  }

  @override
  Future<bool> getReqAuth() async {
    try {
      final raw = await repos.read(key: requestLocalAuth);
      return raw == "1";
    } catch (e) {
      DLog.error("AppSecureStorage getReqAuth error: $e");
      return false;
    }
  }

  @override
  Future<void> onLogOutClear() async {
    try {
      await Future.wait([
        repos.delete(key: appAccessToken),
        repos.delete(key: loggedInProfile),
        repos.delete(key: requestLocalAuth),
      ]);
    } catch (e) {
      DLog.error("AppSecureStorage onLogOutClear error: $e");
    }
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

  static const String onboardingCompletedKey = "onboarding_completed";

  @override
  Future<bool> getOnboardingCompleted() async {
    await initComplete.future;
    return prefs.getBool(onboardingCompletedKey) ?? false;
  }

  @override
  Future<void> saveOnboardingCompleted(bool value) async {
    await initComplete.future;
    await prefs.setBool(onboardingCompletedKey, value);
  }
}
