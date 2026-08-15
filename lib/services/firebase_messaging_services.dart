import 'dart:async';
import 'dart:convert';

import 'package:s_map/commons/cubits/app_cubit/app_cubit.dart';
import 'package:s_map/commons/cubits/auth_cubit/auth_cubit.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/notification_model.dart';
import 'package:s_map/routers/routers.dart';
import 'package:s_map/services/local_notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';

class FirebaseMessagingService implements IFirebaseMessagingService {
  FirebaseMessagingService._();

  static FirebaseMessagingService instance =
      FirebaseMessagingService._();

  FirebaseMessaging? _messaging;

  Completer fmsCompleter = Completer();

  BuildContext get routeContext => Routes.instance.context;

  AppCubit get appCubit => routeContext.read<AppCubit>();

  AuthCubit get authCubit => routeContext.read<AuthCubit>();

  @override
  BehaviorSubject<NotificationModel?> comingNotificationListener = BehaviorSubject.seeded(null);

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
          if (message.notification?.title != null) {
            LocalNotificationService.instance.showNotification(
              title: message.notification?.title,
              body: message.notification?.body,
              payload: jsonEncode(message.data),
            );
          }
          final model = NotificationModel.fromJson(message.data)
            ..jsonData = message.data
            ..onListen();

          comingNotificationListener.value = model;
        });

        //5. background message using backgroundHandler
        FirebaseMessaging.onBackgroundMessage(
            _firebaseMessagingBackgroundHandler);

        //6. On message open app
        FirebaseMessaging.onMessageOpenedApp
            .listen((RemoteMessage message) async {
          DLog.info(
              '**onMessageOpenedApp** Called ${message.data.runtimeType}');

          //7. pass data into model
          NotificationModel? appNotification =
              NotificationModel.fromJson(message.data);
          appNotification.jsonData = message.data;

          onClickNotification(appNotification, openFromBanner: true);
          //8. Route handle
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
      NotificationModel notificationModel,
      {bool openFromBanner = false}) async {
    await fmsCompleter.future;
    return Routes.instance.showLoadingDepend(notificationModel.onOpen());
  }

  @override
  Future<void> onAppStartedWithNotification() async {
    try {
      final initFromFB = await _messaging?.getInitialMessage();
      if (initFromFB != null) {
        final initMessage = NotificationModel.fromJson(initFromFB.data);
        initMessage.jsonData = initFromFB.data;
        onClickNotification(initMessage, openFromBanner: true);
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

extension NotificationHandle on NotificationModel {
  BuildContext get routeContext => Routes.instance.context;

  AppCubit get appCubit => routeContext.read<AppCubit>();

  AuthCubit get authCubit => routeContext.read<AuthCubit>();

  Future<void> onOpen() async {
    // Handle opening notification
  }

  Future<NotificationModel> read() async {
    return this;
  }

  Future<void> onListen() async {
    // Handle background notification receive
  }
}

extension CompleteAfter<T> on Completer<T> {
  void completeAfter(T value) {
    if (isCompleted) return;
    complete(value);
  }
}
