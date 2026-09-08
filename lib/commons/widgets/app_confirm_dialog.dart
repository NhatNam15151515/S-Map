import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/generated/locale_keys.g.dart';

/// Hộp thoại xác nhận hành động dùng chung (Generic Confirmation Dialog).
///
/// Chuẩn hóa giao diện AlertDialog theo Material 3:
/// - Bo góc 20, nền theo `colorScheme.surface`, đổ bóng nhẹ.
/// - Hỗ trợ hiển thị icon minh họa phía trên (tùy chọn).
/// - Nút Hủy (TextButton) và nút Xác nhận (ElevatedButton).
/// - Chế độ `isDestructive`: tự động đổi màu nút xác nhận sang `colorScheme.error`
///   khi thực hiện thao tác xóa hoặc hủy dữ liệu.
class AppConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? confirmText;
  final String? cancelText;
  final bool isDestructive;
  final IconData? icon;
  final Key? confirmKey;
  final Key? cancelKey;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText,
    this.cancelText,
    this.isDestructive = false,
    this.icon,
    this.confirmKey,
    this.cancelKey,
    this.onConfirm,
    this.onCancel,
  });

  /// Phương thức tiện ích để hiển thị hộp thoại xác nhận.
  ///
  /// Trả về `Future<bool?>`: `true` nếu người dùng ấn Xác nhận, `false` nếu Hủy hoặc đóng.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    bool isDestructive = false,
    IconData? icon,
    Key? confirmKey,
    Key? cancelKey,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppConfirmDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        isDestructive: isDestructive,
        icon: icon,
        confirmKey: confirmKey,
        cancelKey: cancelKey,
        onConfirm: onConfirm,
        onCancel: onCancel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final primaryActionColor =
        isDestructive ? colorScheme.error : colorScheme.primary;
    final onPrimaryActionColor =
        isDestructive ? colorScheme.onError : colorScheme.onPrimary;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      icon: icon != null
          ? Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryActionColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 24,
                color: primaryActionColor,
              ),
            )
          : null,
      title: Text(
        title,
        style: colorScheme.onSurface.textTheme.boldStyle.copyWith(
          fontSize: 16,
        ),
        textAlign: icon != null ? TextAlign.center : TextAlign.start,
      ),
      content: Text(
        message,
        style: colorScheme.onSurfaceVariant.textTheme.regularStyle.copyWith(
          fontSize: 13,
        ),
        textAlign: icon != null ? TextAlign.center : TextAlign.start,
      ),
      actions: [
        TextButton(
          key: cancelKey,
          onPressed: () {
            context.safePop(false);
            onCancel?.call();
          },
          child: Text(
            cancelText ?? tr(LocaleKeys.cancel),
            style: colorScheme.onSurfaceVariant.textTheme.mediumStyle,
          ),
        ),
        ElevatedButton(
          key: confirmKey,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryActionColor,
            foregroundColor: onPrimaryActionColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          onPressed: () {
            context.safePop(true);
            onConfirm?.call();
          },
          child: Text(
            confirmText ?? tr(LocaleKeys.confirm),
            style: onPrimaryActionColor.textTheme.semiBoldStyle,
          ),
        ),
      ],
    );
  }
}
