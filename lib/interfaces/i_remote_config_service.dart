import 'package:s_map/services/remote_config_service.dart';

abstract class IRemoteConfigService {
  Future<void> initialize();
  Future<void> fetchAndActivate();
  bool get forceLogin;
  bool get maintenance;
  String get appVersion;
  String get termCondition;
  List<HelpCenterQuestion> get helpCenter;
  Future<bool> mustUpdate();
}
