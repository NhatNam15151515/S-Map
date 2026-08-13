import 'dart:async';

import 'package:another_flushbar/flushbar.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/commons/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../mixin/app_mixin.dart';

enum FlushBarStatusType { succeed, error, info, warning }

class PopupUtils with AppMixin {
  BuildContext context;

  PopupUtils(this.context);

  Future showFlushBar({
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
        title ??= "Hoàn tất";
        statusColor = AppColors.sMapTeal;
        break;
      case FlushBarStatusType.error:
        icon = Icons.error_rounded;
        title ??= "Lỗi";
        statusColor = AppColors.googleRed;
        break;
      case FlushBarStatusType.info:
        icon = Icons.info_rounded;
        title ??= "Thông tin";
        statusColor = AppColors.googleBlue;
        break;
      case FlushBarStatusType.warning:
        icon = Icons.warning_rounded;
        title ??= "Thông báo";
        statusColor = AppColors.googleYellow;
        break;
    }
    Completer completer = Completer();
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
      onTap: (value) {
        onTap?.call();
      },
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
    WidgetsBinding.instance.scheduleFrameCallback((timeStamp) {
      flush.show(context).then((value) {
        completer.complete();
      });
    });
    return completer.future;
  }

  static Future showModalBottom({
    required BuildContext context,
    required Widget child,
    required String title,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (context) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: bottomSheetContainer(
            title,
            AppStyle.of(context),
            context,
            child,
          ),
        );
      },
    );
  }

  static Widget bottomSheetContainer(
      String title, AppStyle styles, BuildContext context, Widget child) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height / 1.5,
      ),
      decoration: BoxDecoration(
        color: styles.whiteTextColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style:
                        styles.blackTextColor.textTheme.subTitleStyle.copyWith(
                      fontSize: 18,
                    ),
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceContainer,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.onSurfaceVariant,
                    ),
                    onPressed: () {
                      context.pop();
                    },
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Flexible(child: child),
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }

  Future showConfirmDialog({
    required String content,
    Function? onPressYes,
    Function? onPressNo,
  }) {
    return showDialog(
      useRootNavigator: false,
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: AppColors.sMapLightTeal,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.help_outline_rounded,
                    size: 28,
                    color: AppColors.sMapTeal,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  content,
                  style: styles.blackTextColor.textTheme.textStyle.copyWith(
                    fontSize: 16,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          context.pop();
                          onPressNo?.call();
                        },
                        style: styles.outlineButtonStyle,
                        child: Text(
                          "Huỷ bỏ",
                          style: AppColors
                              .onSurfaceVariant.textTheme.subTitleStyle
                              .copyWith(
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          context.pop();
                          onPressYes?.call();
                        },
                        child: Text(
                          "Xác nhận",
                          style: styles.whiteTextColor.textTheme.subTitleStyle
                              .copyWith(
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future showAlertDialog({
    required String content,
    Function? onPress,
  }) {
    return showDialog(
      useRootNavigator: false,
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: AppColors.sMapLightTeal,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    size: 28,
                    color: AppColors.sMapTeal,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  content,
                  style: styles.blackTextColor.textTheme.textStyle.copyWith(
                    fontSize: 16,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      context.pop();
                      onPress?.call();
                    },
                    child: Text(
                      "Xác nhận",
                      style: styles.whiteTextColor.textTheme.subTitleStyle
                          .copyWith(
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future showTextFieldDialog({
    required String content,
    Function(String)? onPressYes,
    TextInputType? textInputType,
    Function? onPressNo,
    String? init,
  }) {
    final CustomTextEditingController controller =
        CustomTextEditingController(text: init ?? "");
    return showDialog(
      context: context,
      useRootNavigator: false,
      builder: (context) {
        return Dialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  content,
                  style: styles.blackTextColor.textTheme.subTitleStyle.copyWith(
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: controller,
                  focusedBorder: styles.defaultBorder,
                  unfocusedBorder: styles.defaultBorder,
                  textInputType: textInputType,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          context.pop();
                          onPressNo?.call();
                        },
                        style: styles.outlineButtonStyle,
                        child: Text(
                          "Huỷ bỏ",
                          style: AppColors
                              .onSurfaceVariant.textTheme.subTitleStyle
                              .copyWith(
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          context.pop();
                          onPressYes?.call(controller.text);
                        },
                        child: Text(
                          "Xác nhận",
                          style: styles.whiteTextColor.textTheme.subTitleStyle
                              .copyWith(
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ).then((value) {
      controller.dispose();
      return value;
    });
  }
}
