import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AppSecureStorage {
  static const FlutterSecureStorage repos = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  static const String appAccessToken = "appAccessToken";
  static const String loggedInProfile = "loggedInProfile";
  static const String requestLocalAuth = "requestLocalAuth";

  static Future<void> saveAuthToken(String token) async {
    await repos.write(key: appAccessToken, value: token);
  }

  static Future<String?> getStoredAuthToken() async {
    final token = await repos.read(key: appAccessToken);
    return token;
  }

  static Future<void> saveProfile(User user) async {
    await repos.write(key: loggedInProfile, value: jsonEncode(user.toJson()));
  }

  static Future<User?> getStoredProfile() async {
    final rawProfile = await repos.read(key: loggedInProfile);
    if (rawProfile != null) {
      try {
        return User.fromJson(jsonDecode(rawProfile));
      } catch (_) {}
    }
    return null;
  }

  static Future<void> saveReqAuth(bool value) async {
    await repos.write(key: requestLocalAuth, value: value ? "1" : "0");
  }

  static Future<bool> getReqAuth() async {
    final raw = await repos.read(key: requestLocalAuth);
    return raw == "1";
  }

  static Future<void> onLogOutClear() {
    return Future.wait([
      repos.delete(key: appAccessToken),
      repos.delete(key: loggedInProfile),
      repos.delete(key: requestLocalAuth),
    ]);
  }
}

class AppSharedPreferences {
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

  Future<bool> get1stInstall() async {
    await initComplete.future;
    return prefs.getBool(firstInstall) ?? true;
  }

  Future<void> save1stInstall() async {
    await initComplete.future;
    await prefs.setBool(firstInstall, false);
  }
}
