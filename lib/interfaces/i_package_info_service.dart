import 'package:package_info_plus/package_info_plus.dart';

abstract class IPackageInfoService {
  PackageInfo? get packageInfo;
  String get appName;
  String get packageName;
  String get version;
  String get buildNumber;
  Future<void> init();
}
