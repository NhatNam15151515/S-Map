import 'package:easy_localization/easy_localization.dart';
import 'package:s_map/commons/enums/enums.dart';
import 'package:s_map/generated/locale_keys.g.dart';

enum NotificationTab {
  system,
  customer;

  String get title {
    switch (this) {
      case system:
        return tr(LocaleKeys.notification_tabs_tab_system);
      case customer:
        return tr(LocaleKeys.notification_tabs_tab_customer);
    }
  }
}

class NotificationModel {
  String? id;
  String? title;
  String? content;
  NotificationType? notiType;
  DateTime? createdDate;
  Map<String, dynamic>? jsonData;

  NotificationModel({
    this.id,
    this.title,
    this.content,
    this.notiType,
    this.createdDate,
    this.jsonData,
  });

  NotificationModel.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString();
    title = json['title'] ?? "";
    content = json['content'] ?? "";
    notiType = json['type'] != null
        ? NotificationType.values.firstWhere(
            (e) => e.id == json['type'],
            orElse: () => NotificationType.system,
          )
        : NotificationType.system;
    createdDate = json['createdDate'] != null
        ? DateTime.tryParse(json['createdDate'].toString()) ?? DateTime.now()
        : DateTime.now();
    jsonData = json;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['title'] = title;
    data['content'] = content;
    data['type'] = notiType?.id;
    data['createdDate'] = createdDate?.toIso8601String();
    return data;
  }
}
