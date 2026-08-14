abstract class ILocalNotificationService {
  Future<void> init();
  Future<void> showNotification({String? title, String? body, String? payload});
}
