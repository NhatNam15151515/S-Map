import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/cupertino.dart';
import 'package:s_map/interfaces/i_remote_config_service.dart';

import 'package_info_service.dart';

class RemoteConfigService implements IRemoteConfigService {
  RemoteConfigService._();

  static RemoteConfigService? _instance;
  factory RemoteConfigService() => _instance ??= RemoteConfigService._();

  FirebaseRemoteConfig? get _remoteConfig {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseRemoteConfig.instance;
      }
    } catch (_) {}
    return null;
  }

  StreamSubscription<RemoteConfigUpdate>? configChangedStream;

  String _getString(String key) {
    try {
      return _remoteConfig?.getString(key) ?? "";
    } catch (_) {
      return "";
    }
  }

  bool _getBool(String key) {
    try {
      return _remoteConfig?.getBool(key) ?? false;
    } catch (_) {
      return false;
    }
  }

  void _setListener() {
    try {
      configChangedStream = _remoteConfig?.onConfigUpdated.listen((event) async {
        await _remoteConfig?.activate();
        debugPrint('The config has been updated.');
      });
    } catch (e) {
      debugPrint('RemoteConfig listener error: $e');
    }
  }

  Future<void> _setDefaults() async {
    try {
      await _remoteConfig?.setDefaults(
        {
          RemoteConfigKeys.forceLogin: false,
          RemoteConfigKeys.appVersion: PackageInfoService.instance.version,
        },
      );
    } catch (e) {
      debugPrint('RemoteConfig setDefaults error: $e');
    }
  }

  @override
  Future<void> fetchAndActivate() async {
    try {
      bool? updated = await _remoteConfig?.fetchAndActivate();
      if (updated == true) {
        debugPrint('The config has been updated.');
      }
    } catch (e) {
      debugPrint('RemoteConfig fetch error: $e');
    }
  }

  @override
  Future<void> initialize() async {
    try {
      await PackageInfoService.instance.initCompleter.future;
      _setListener();
      await _setDefaults();
      await fetchAndActivate();
    } catch (e) {
      debugPrint('RemoteConfig initialize error: $e');
    }
  }

  @override
  bool get forceLogin => _getBool(RemoteConfigKeys.forceLogin);

  @override
  List<HelpCenterQuestion> get helpCenter {
    try {
      final value = _remoteConfig?.getValue(RemoteConfigKeys.helpCenter);
      final decoded = (value != null && value.asString().isNotEmpty)
          ? jsonDecode(value.asString())
          : null;
      if (decoded is Map &&
          decoded["term"] is List &&
          (decoded["term"] as List).isNotEmpty) {
        final list = <HelpCenterQuestion>[];
        decoded["term"].forEach((e) {
          final model = HelpCenterQuestion(
            q: e["Q"],
            a: e["A"],
          );
          list.add(model);
        });
        return list;
      }
    } catch (_) {}
    return [];
  }

  @override
  bool get maintenance => _getBool(RemoteConfigKeys.maintenance);
  @override
  String get appVersion => _getString(RemoteConfigKeys.appVersion);
  @override
  String get termCondition => _getString(RemoteConfigKeys.termCondition);

  @override
  Future<bool> mustUpdate() async {
    try {
      await PackageInfoService.instance.initCompleter.future;
      final localVer = PackageInfoService.instance.version;
      if (appVersion.isNotEmpty && localVer != appVersion) {
        return true;
      }
    } catch (_) {}
    return false;
  }
}

class RemoteConfigKeys {
  static const String forceLogin = 'forceLogin';
  static const String appVersion = 'app_version';
  static const String termCondition = 'term_condition';
  static const String helpCenter = 'help_center';
  static const String maintenance = "maintenance";
}

class HelpCenterQuestion {
  final String q;
  final String a;

  HelpCenterQuestion({required this.q, required this.a});
}
