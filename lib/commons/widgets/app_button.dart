import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';

enum AppButtonVariant { primary, outlined, text }

/// Reusable Dumb Button Widget chuẩn hoá cho toàn bộ ứng dụng.
///
/// Hỗ trợ 3 biến thể: Primary (Elevated/Filled), Outlined, và TextButton.
/// Tự động xử lý trạng thái [isLoading] (hiển thị spinner và disable click).
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? icon;
  final AppButtonVariant variant;
  final double? width;
  final double? height;
  final double? borderRadius;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final TextStyle? textStyle;
  final double elevation;
  final EdgeInsetsGeometry? padding;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.width = double.infinity,
    this.height = 50,
    this.borderRadius = 25,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.textStyle,
    this.elevation = 0,
    this.padding,
  });

  const AppButton.primary({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width = double.infinity,
    this.height = 50,
    this.borderRadius = 25,
    this.backgroundColor,
    this.textColor,
    this.textStyle,
    this.elevation = 0,
    this.padding,
  })  : variant = AppButtonVariant.primary,
        borderColor = null;

  const AppButton.outlined({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width = double.infinity,
    this.height = 50,
    this.borderRadius = 25,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.textStyle,
    this.elevation = 0,
    this.padding,
  }) : variant = AppButtonVariant.outlined;

  const AppButton.text({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height,
    this.textColor,
    this.textStyle,
    this.padding,
  })  : variant = AppButtonVariant.text,
        borderRadius = null,
        backgroundColor = null,
        borderColor = null,
        elevation = 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final effectiveRadius = borderRadius ?? 25;
    final isEnabled = !isLoading && onPressed != null;

    switch (variant) {
      case AppButtonVariant.primary:
        final bg = backgroundColor ?? colorScheme.primary;
        final fg = textColor ?? colorScheme.onPrimary;

        return SizedBox(
          width: width,
          height: height,
          child: ElevatedButton(
            onPressed: isEnabled ? onPressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: bg,
              foregroundColor: fg,
              disabledBackgroundColor: bg.withValues(alpha: 0.6),
              disabledForegroundColor: fg.withValues(alpha: 0.8),
              elevation: elevation,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(effectiveRadius),
              ),
              padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: _buildContent(fg),
          ),
        );

      case AppButtonVariant.outlined:
        final bg = backgroundColor ?? colorScheme.surface;
        final fg = textColor ?? colorScheme.onSurface;
        final border = borderColor ?? colorScheme.outline.withAlpha(80);

        return SizedBox(
          width: width,
          height: height,
          child: OutlinedButton(
            onPressed: isEnabled ? onPressed : null,
            style: OutlinedButton.styleFrom(
              backgroundColor: bg,
              foregroundColor: fg,
              disabledForegroundColor: fg.withValues(alpha: 0.5),
              elevation: elevation,
              side: BorderSide(color: border, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(effectiveRadius),
              ),
              padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: _buildContent(fg),
          ),
        );

      case AppButtonVariant.text:
        final fg = textColor ?? colorScheme.primary;

        return SizedBox(
          width: width,
          height: height,
          child: TextButton(
            onPressed: isEnabled ? onPressed : null,
            style: TextButton.styleFrom(
              foregroundColor: fg,
              disabledForegroundColor: fg.withValues(alpha: 0.5),
              padding: padding ??
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: _buildContent(fg),
          ),
        );
    }
  }

  Widget _buildContent(Color fallbackColor) {
    if (isLoading) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(fallbackColor),
        ),
      );
    }

    final effectiveTextStyle = textStyle ??
        fallbackColor.textTheme.boldStyle.copyWith(
          fontSize: 15,
        );

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon!,
          const SizedBox(width: 10),
          Text(text, style: effectiveTextStyle),
        ],
      );
    }

    return Text(text, style: effectiveTextStyle);
  }
}
