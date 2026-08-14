import 'package:s_map/interfaces/i_notification_repos.dart';
import 'package:s_map/models/notification_model.dart';
import 'package:s_map/services/firebase_firestore_service.dart';

// Backward compatibility alias
typedef NotificationRepos = INotificationRepos;

class NotificationReposImpl implements INotificationRepos {
  final FireStoreService _fireStore = FireStoreService();

  @override
  Future<(List<NotificationModel>, int)> getSystemNotification({int page = 1, int limit = 10}) async {
    final list = await _fireStore.getNotifications(limit: limit);
    return (list, list.length);
  }

  @override
  Future<(List<NotificationModel>, int)> getCustomerNotification({int page = 1, int limit = 10}) async {
    final list = await _fireStore.getNotifications(limit: limit);
    return (list, list.length);
  }
}
