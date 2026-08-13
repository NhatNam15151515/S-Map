import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/commons/widgets/app_bar.dart';
import 'package:s_map/models/notification_model.dart';
import 'package:flutter/material.dart';

import '../../../commons/mixin/app_mixin.dart';

class NotificationDetailScreen extends StatefulWidget {
  static const String path = '/NotificationDetailScreen';

  final NotificationModel notificationModel;

  const NotificationDetailScreen({super.key, required this.notificationModel});

  @override
  _NotificationDetailScreenState createState() => _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> with AppMixin {

  NotificationModel get item => widget.notificationModel;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleBackAppBar(title: "Thông báo"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon + Title row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.sMapLightTeal,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.notifications_rounded,
                      size: 24,
                      color: AppColors.sMapTeal,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${item.title}",
                          style: styles.blackTextColor.textTheme.subTitleStyle.copyWith(
                            fontSize: 17,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.createdDate != null
                              ? "${item.createdDate!.hour.toString().padLeft(2, '0')}:${item.createdDate!.minute.toString().padLeft(2, '0')} - ${item.createdDate!.day}/${item.createdDate!.month}/${item.createdDate!.year}"
                              : "",
                          style: AppColors.onSurfaceVariant.textTheme.captionStyle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: AppColors.outlineVariant.withAlpha(128), height: 1),
              const SizedBox(height: 16),
              Text(
                "${item.content}",
                style: styles.blackTextColor.textTheme.textStyle.copyWith(
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
