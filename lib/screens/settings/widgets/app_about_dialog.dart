import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';

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

    return AppInfoDialog(
      icon: Icons.map_rounded,
      title: appName,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(LocaleKeys.versionPrefix, args: [appVersion]),
            style: colorScheme.onSurfaceVariant.textTheme.textStyle,
          ),
          const SizedBox(height: 12),
          Text(
            tr(LocaleKeys.aboutAppDesc),
            style: colorScheme.onSurface.textTheme.textStyle.copyWith(
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
