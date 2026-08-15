import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';

import 'popups/app_bottom_sheet_util.dart';
import 'popups/app_dialogs.dart';
import 'popups/app_flushbar.dart';

export 'popups/app_bottom_sheet_util.dart';
export 'popups/app_dialogs.dart';
export 'popups/app_flushbar.dart';

/// Facade for all popup, dialog, bottom sheet, and flushbar utilities.
/// Maintains 100% backward compatibility for all existing callers.
class PopupUtils {
  final BuildContext context;

  const PopupUtils(this.context);

  Future<dynamic> showFlushBar({
    required String message,
    String? title,
    FlushBarStatusType flushBarStatusType = FlushBarStatusType.succeed,
    FlushbarPosition position = FlushbarPosition.TOP,
    Duration? duration,
    Function? onTap,
  }) {
    return AppFlushbar(context).show(
      message: message,
      title: title,
      flushBarStatusType: flushBarStatusType,
      position: position,
      duration: duration,
      onTap: onTap,
    );
  }

  static Future<T?> showModalBottom<T>({
    required BuildContext context,
    required Widget child,
    required String title,
  }) {
    return AppBottomSheetUtil.showModalBottom<T>(
      context: context,
      child: child,
      title: title,
    );
  }

  static Widget bottomSheetContainer(
    String title,
    AppStyle styles,
    BuildContext context,
    Widget child,
  ) {
    return AppBottomSheetUtil.bottomSheetContainer(
      title,
      styles,
      context,
      child,
    );
  }

  Future<dynamic> showConfirmDialog({
    required String content,
    Function? onPressYes,
    Function? onPressNo,
  }) {
    return AppDialogs(context).showConfirmDialog(
      content: content,
      onPressYes: onPressYes,
      onPressNo: onPressNo,
    );
  }

  Future<dynamic> showAlertDialog({
    required String content,
    Function? onPress,
  }) {
    return AppDialogs(context).showAlertDialog(
      content: content,
      onPress: onPress,
    );
  }

  Future<dynamic> showTextFieldDialog({
    required String content,
    Function(String)? onPressYes,
    TextInputType? textInputType,
    Function? onPressNo,
    String? init,
  }) {
    return AppDialogs(context).showTextFieldDialog(
      content: content,
      onPressYes: onPressYes,
      textInputType: textInputType,
      onPressNo: onPressNo,
      init: init,
    );
  }
}
