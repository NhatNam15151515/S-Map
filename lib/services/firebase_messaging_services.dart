import 'dart:async';

import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:rxdart/rxdart.dart';

class FirebaseMessagingService implements IFirebaseMessagingService {
  FirebaseMessagingService._();

  static FirebaseMessagingService instance =
      FirebaseMessagingService._();

  FirebaseMessaging? _messaging;

  /// Optional delegate to display loading overlay when handling notification tap
  static Future<void> Function(Future<void> action)? loadingOverlayHandler;

  @override
  Completer<bool> fmsCompleter = Completer<bool>();

  @override
  BehaviorSubject<Map<String, dynamic>?> comingNotificationListener =
      BehaviorSubject.seeded(null);

  @override
  Future<void> init() async {
    try {
      // Instantiate Firebase Messaging
      _messaging = FirebaseMessaging.instance;

      // On iOS, this helps to take the user permissions
      NotificationSettings settings =
          await _messaging!.requestPermission(
        alert: true,
        badge: true,
        provisional: false,
        sound: true,
      );

      // 4. on Message Listen
      if (settings.authorizationStatus ==
          AuthorizationStatus.authorized) {
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          DLog.info('**onMessage** Called ${message.data}');
          comingNotificationListener.value = message.data;
        });

        //5. background message using backgroundHandler
        FirebaseMessaging.onBackgroundMessage(
            _firebaseMessagingBackgroundHandler);

        //6. On message open app
        FirebaseMessaging.onMessageOpenedApp
            .listen((RemoteMessage message) async {
          DLog.info(
              '**onMessageOpenedApp** Called ${message.data.runtimeType}');
          onClickNotification(message.data, openFromBanner: true);
        });
      } else {
        DLog.info(
          'Messaging Permission -> User declined or has not accepted permission',
        );
      }
    } catch (e) {
      DLog.error('FirebaseMessaging init error: $e');
    }
  }

  //9. get FCM Token
  @override
  Future<String?> getToken() async {
    try {
      final fcmToken = await _messaging?.getToken();
      return fcmToken;
    } catch (e) {
      DLog.error('Error getting FCM token: $e');
      return null;
    }
  }

  @override
  Future<void> onClickNotification(
      Map<String, dynamic> data,
      {bool openFromBanner = false}) async {
    await fmsCompleter.future;
  }

  @override
  Future<void> onAppStartedWithNotification() async {
    try {
      final initFromFB = await _messaging?.getInitialMessage();
      if (initFromFB != null) {
        onClickNotification(initFromFB.data, openFromBanner: true);
      }
    } catch (e) {
      DLog.error('Error checking initial notification: $e');
    }
  }
}

//10. backgroundHandle
Future _firebaseMessagingBackgroundHandler(
    RemoteMessage message) async {
  await Firebase.initializeApp();

  DLog.info(
      'MessageID Handling a background message: ${message.messageId}');
}

extension CompleteAfter<T> on Completer<T> {
  void completeAfter(T value) {
    if (isCompleted) return;
    complete(value);
  }
}

