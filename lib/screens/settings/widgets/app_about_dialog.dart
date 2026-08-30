import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';

class AppAboutDialog extends StatelessWidget {
  final String appName;
  final String appVersion;

  const AppAboutDialog({
    super.key,
    required this.appName,
    required this.appVersion,
  });

  static Future<void> show(
    BuildContext context, {
    required String appName,
    required String appVersion,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => AppAboutDialog(
        appName: appName,
        appVersion: appVersion,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Icon(Icons.map_rounded, color: colorScheme.primary, size: 28),
          const SizedBox(width: 10),
          Text(
            appName,
            style: colorScheme.onSurface.textTheme.boldStyle.copyWith(
              fontSize: 18,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Phiên bản: $appVersion',
            style: colorScheme.onSurfaceVariant.textTheme.textStyle,
          ),
          const SizedBox(height: 12),
          Text(
            'S-Map là ứng dụng bản đồ số và dẫn đường ngoại tuyến tối ưu cho người dùng Việt Nam. Hỗ trợ tìm kiếm địa điểm, dẫn đường bằng giọng nói cho xe máy và quản lý bản đồ offline 63 tỉnh thành.',
            style: colorScheme.onSurface.textTheme.textStyle.copyWith(
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => context.safePop(),
          child: Text(
            'Đóng',
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
