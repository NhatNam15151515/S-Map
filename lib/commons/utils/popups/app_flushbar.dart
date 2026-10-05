import 'dart:async';
import 'package:another_flushbar/flushbar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/generated/locale_keys.g.dart';

enum FlushBarStatusType { succeed, error, info, warning }

class AppFlushbar {
  final BuildContext context;

  const AppFlushbar(this.context);

  Future<dynamic> show({
    required String message,
    String? title,
    FlushBarStatusType flushBarStatusType = FlushBarStatusType.succeed,
    FlushbarPosition position = FlushbarPosition.TOP,
    Duration? duration,
    Function? onTap,
  }) {
    IconData icon;
    Color statusColor;

    switch (flushBarStatusType) {
      case FlushBarStatusType.succeed:
        icon = Icons.check_circle_rounded;
        title ??= tr(LocaleKeys.common_success);
        statusColor = AppColors.sMapTeal;
        break;
      case FlushBarStatusType.error:
        icon = Icons.error_rounded;
        title ??= tr(LocaleKeys.common_error);
        statusColor = AppColors.googleRed;
        break;
      case FlushBarStatusType.info:
        icon = Icons.info_rounded;
        title ??= tr(LocaleKeys.common_info);
        statusColor = AppColors.googleBlue;
        break;
      case FlushBarStatusType.warning:
        icon = Icons.warning_rounded;
        title ??= tr(LocaleKeys.common_notification);
        statusColor = AppColors.googleYellow;
        break;
    }

    final completer = Completer<dynamic>();
    final styles = AppStyle.of(context);

    final flush = Flushbar(
      boxShadows: [
        BoxShadow(
          color: Colors.black.withAlpha(20),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
      forwardAnimationCurve: Curves.easeOutCubic,
      reverseAnimationCurve: Curves.easeInCubic,
      shouldIconPulse: false,
      onTap: (value) => onTap?.call(),
      backgroundColor: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: statusColor.withAlpha(25),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: statusColor,
        ),
      ),
      borderRadius: BorderRadius.circular(16),
      flushbarPosition: position,
      duration: duration ?? const Duration(seconds: 3),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      messageText: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: styles.blackTextColor.textTheme.subTitleStyle.copyWith(
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            message,
            style: AppColors.onSurfaceVariant.textTheme.textStyle.copyWith(
              fontSize: 13,
            ),
          ),
        ],
      ),
    );

    WidgetsBinding.instance.scheduleFrameCallback((_) {
      flush.show(context).then((value) {
        completer.complete(value);
      });
    });

    return completer.future;
  }
}
