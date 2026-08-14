import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:s_map/flavor/flavor.dart';
import 'package:s_map/interfaces/i_package_info_service.dart';

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
    packageInfo = await PackageInfo.fromPlatform();
    initCompleter.complete(true);
  }

  @override
  String get appName => packageInfo?.appName ?? "-";
  @override
  String get packageName => packageInfo?.packageName ?? "-";
  @override
  String get version => "${packageInfo?.version}($buildNumber)${Flavor.instance.subEnv}";
  @override
  String get buildNumber => packageInfo?.buildNumber ?? "-";
}
