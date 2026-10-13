import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:s_map/flavor/flavor.dart';
import 'package:s_map/interfaces/interfaces.dart';

class PackageInfoService implements IPackageInfoService {
  PackageInfoService._() {
    init();
  }

  @override
  PackageInfo? packageInfo;
  Completer<bool> initCompleter = Completer();

  static PackageInfoService instance = PackageInfoService._();

  @override
  Future<void> init() async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      packageInfo = await PackageInfo.fromPlatform();
    } catch (_) {}
    if (!initCompleter.isCompleted) {
      initCompleter.complete(true);
    }
  }

  @override
  String get appName {
    if (packageInfo?.appName != null &&
        packageInfo!.appName.isNotEmpty &&
        packageInfo!.appName != "-") {
      return packageInfo!.appName;
    }
    try {
      if (Flavor.instance.displayName.isNotEmpty) {
        return Flavor.instance.displayName;
      }
    } catch (_) {}
    return "S-Map";
  }

  @override
  String get packageName => packageInfo?.packageName ?? "-";

  @override
  String get version {
    String subEnv = "";
    try {
      subEnv = Flavor.instance.subEnv;
    } catch (_) {}
    return "${packageInfo?.version ?? '-'}($buildNumber)$subEnv";
  }

  @override
  String get buildNumber => packageInfo?.buildNumber ?? "-";
}
