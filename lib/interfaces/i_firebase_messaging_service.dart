import 'dart:async';
import 'package:rxdart/rxdart.dart';

abstract class IFirebaseMessagingService {
  Completer<bool> get fmsCompleter;
  BehaviorSubject<Map<String, dynamic>?> get comingNotificationListener;
  Future<void> init();
  Future<String?> getToken();
  Future<void> onClickNotification(
    Map<String, dynamic> data, {
    bool openFromBanner = false,
  });
  Future<void> onAppStartedWithNotification();
}
