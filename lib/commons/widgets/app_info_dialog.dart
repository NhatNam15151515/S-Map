import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/widgets/app_button.dart';
import 'package:s_map/generated/locale_keys.g.dart';

/// Reusable Dumb Dialog chuẩn Material 3 hiển thị thông tin, chính sách hoặc thông báo 1 hành động.
class AppInfoDialog extends StatelessWidget {
  final String title;
  final Widget? content;
  final String? message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onClose;

  const AppInfoDialog({
    super.key,
    required this.title,
    this.content,
    this.message,
    this.icon,
    this.actionLabel,
    this.onClose,
  }) : assert(
          content != null || message != null,
          'Cần cung cấp ít nhất một trong hai: content hoặc message',
        );

  /// Hiển thị hộp thoại thông tin một cách tiện lợi.
  static Future<void> show(
    BuildContext context, {
    required String title,
    Widget? content,
    String? message,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onClose,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => AppInfoDialog(
        title: title,
        content: content,
        message: message,
        icon: icon,
        actionLabel: actionLabel,
        onClose: onClose,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final effectiveActionLabel = actionLabel ?? tr(LocaleKeys.close);

    final titleWidget = icon != null
        ? Row(
            children: [
              Icon(icon, color: colorScheme.primary, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: colorScheme.onSurface.textTheme.boldStyle.copyWith(
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          )
        : Text(
            title,
            style: colorScheme.onSurface.textTheme.boldStyle.copyWith(
              fontSize: 18,
            ),
          );

    final contentWidget = content ??
        SingleChildScrollView(
          child: Text(
            message ?? '',
            style: colorScheme.onSurface.textTheme.textStyle.copyWith(
              fontSize: 14,
              height: 1.4,
            ),
          ),
        );

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: titleWidget,
      content: contentWidget,
      actions: [
        AppButton.text(
          text: effectiveActionLabel,
          textColor: colorScheme.primary,
          textStyle: TextStyle(
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
          onPressed: onClose ?? () => context.safePop(),
        ),
      ],
    );
  }
}
