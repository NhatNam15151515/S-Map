import 'package:s_map/commons/cubits/app_cubit/app_cubit.dart';
import 'package:s_map/models/notification_model.dart';
import 'package:flutter/foundation.dart';

class NotificationController {
  final AppCubit appCubit;

  final ValueNotifier<int> unReadSystem = ValueNotifier(0);
  final ValueNotifier<int> unReadCustomer = ValueNotifier(0);

  NotificationController(this.appCubit);

  int get unread => unReadSystem.value + unReadCustomer.value;
  bool get showBadge => unread != 0;

  void applyStats(NotificationTab type, int? count) {
    switch (type) {
      case NotificationTab.system:
        unReadSystem.value = count ?? 0;
        break;
      case NotificationTab.customer:
        unReadCustomer.value = count ?? 0;
        break;
    }
  }
}
