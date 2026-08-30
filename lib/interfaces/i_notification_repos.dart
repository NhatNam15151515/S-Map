import 'package:s_map/models/notification_model.dart';

abstract class INotificationRepos {
  Future<(List<NotificationModel>, int)> getSystemNotification({int page = 1, int limit = 10});
  Future<(List<NotificationModel>, int)> getCustomerNotification({int page = 1, int limit = 10});
}
