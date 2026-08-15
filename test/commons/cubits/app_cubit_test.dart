import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/rxdart.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

class MockFirebaseMessagingService implements IFirebaseMessagingService {
  @override
  Completer<bool> fmsCompleter = Completer<bool>();

  bool onAppStartedCalled = false;

  @override
  BehaviorSubject<NotificationModel?> comingNotificationListener =
      BehaviorSubject<NotificationModel?>.seeded(null);

  @override
  Future<void> init() async {}

  @override
  Future<String?> getToken() async => 'mock_token';

  @override
  Future<void> onClickNotification(
    NotificationModel notificationModel, {
    bool openFromBanner = false,
  }) async {}

  @override
  Future<void> onAppStartedWithNotification() async {
    onAppStartedCalled = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppCubit Tests - onMainScreenMounted', () {
    test('onMainScreenMounted completes fmsCompleter and calls onAppStartedWithNotification', () {
      final mockMessaging = MockFirebaseMessagingService();
      final appCubit = AppCubit();

      expect(mockMessaging.fmsCompleter.isCompleted, isFalse);
      expect(mockMessaging.onAppStartedCalled, isFalse);

      appCubit.onMainScreenMounted(messagingService: mockMessaging);

      expect(mockMessaging.fmsCompleter.isCompleted, isTrue);
      expect(mockMessaging.onAppStartedCalled, isTrue);

      appCubit.close();
    });
  });
}
