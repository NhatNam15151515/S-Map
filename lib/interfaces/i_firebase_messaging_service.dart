import 'package:rxdart/rxdart.dart';
import 'package:s_map/models/notification_model.dart';

abstract class IFirebaseMessagingService {
  BehaviorSubject<NotificationModel?> get comingNotificationListener;
  Future<void> init();
  Future<String?> getToken();
  Future<void> onClickNotification(
    NotificationModel notificationModel, {
    bool openFromBanner = false,
  });
  Future<void> onAppStartedWithNotification();
}
