import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class AppDialogs {
  final BuildContext context;

  const AppDialogs(this.context);

  Future<dynamic> showConfirmDialog({
    required String content,
    Function? onPressYes,
    Function? onPressNo,
  }) {
    final styles = AppStyle.of(context);
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
                          tr(LocaleKeys.common_cancel),
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
                          tr(LocaleKeys.common_confirm),
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

  Future<dynamic> showAlertDialog({
    required String content,
    Function? onPress,
  }) {
    final styles = AppStyle.of(context);
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
                      tr(LocaleKeys.common_confirm),
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

  Future<dynamic> showTextFieldDialog({
    required String content,
    Function(String)? onPressYes,
    TextInputType? textInputType,
    Function? onPressNo,
    String? init,
  }) {
    final styles = AppStyle.of(context);
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
                          tr(LocaleKeys.common_cancel),
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
                          tr(LocaleKeys.common_confirm),
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

