import 'package:s_map/models/user.dart';

abstract class IFirebaseAnalyticsService {
  Future init();
  Future resetUserDetail({User? profile});
  Future logEvent(String name, Map<String, dynamic> params);
}
