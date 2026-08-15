import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:s_map/models/models.dart';

abstract class IFirebaseMessagingService {
  Completer<bool> get fmsCompleter;
  BehaviorSubject<NotificationModel?> get comingNotificationListener;
  Future<void> init();
  Future<String?> getToken();
  Future<void> onClickNotification(
    NotificationModel notificationModel, {
    bool openFromBanner = false,
  });
  Future<void> onAppStartedWithNotification();
}
