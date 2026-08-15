/// Data model for a single help center Q&A item.
///
/// Moved from [remote_config_service.dart] to [models/] so that
/// [IRemoteConfigService] can reference it without importing the
/// services layer (which would violate the layering rules).
class HelpCenterQuestion {
  final String q;
  final String a;

  HelpCenterQuestion({required this.q, required this.a});
}

/// Keys used to fetch values from Firebase Remote Config.
///
/// Kept alongside [HelpCenterQuestion] since they are domain constants,
/// not implementation details of the service.
class RemoteConfigKeys {
  static const String forceLogin = 'forceLogin';
  static const String appVersion = 'app_version';
  static const String termCondition = 'term_condition';
  static const String helpCenter = 'help_center';
  static const String maintenance = 'maintenance';
}
