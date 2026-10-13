import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';

/// Reusable Dumb Widget cho các mục trong danh sách cài đặt / menu tài khoản.
class AppSettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDestructive;
  final bool showChevron;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  const AppSettingTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.isDestructive = false,
    this.showChevron = true,
    this.iconColor,
    this.iconBackgroundColor,
    this.padding,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final activeColor = iconColor ??
        (isDestructive ? colorScheme.error : colorScheme.primary);
    final activeBg = iconBackgroundColor ??
        activeColor.withValues(alpha: 0.12);
    final textColor =
        isDestructive ? colorScheme.error : colorScheme.onSurface;
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(16);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: effectiveBorderRadius,
        onTap: onTap,
        child: Padding(
          padding: padding ??
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: activeBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: activeColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: textColor.textTheme.boldStyle
                          .copyWith(fontSize: 15),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: colorScheme.onSurfaceVariant.textTheme
                            .captionStyle,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (!isDestructive && showChevron)
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card bọc các item cài đặt / menu dạng nhóm.
class AppSettingGroup extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final bool hasBorder;

  const AppSettingGroup({
    super.key,
    required this.children,
    this.margin,
    this.borderRadius,
    this.backgroundColor,
    this.hasBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(16);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? colorScheme.surface,
        borderRadius: effectiveBorderRadius,
        border: hasBorder
            ? Border.all(
                color: colorScheme.outline.withAlpha(50),
                width: 0.5,
              )
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// Đường phân cách giữa các item cài đặt với lề thụt vào khớp với vị trí text.
class AppSettingDivider extends StatelessWidget {
  final double indent;
  final double height;
  final Color? color;

  const AppSettingDivider({
    super.key,
    this.indent = 60.0,
    this.height = 0.5,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Divider(
        height: height,
        color: color ?? colorScheme.outline.withValues(alpha: 0.25),
      ),
    );
  }
}

/// Tiêu đề phân đoạn của nhóm cài đặt (Settings Section Header).
class AppSettingSectionTitle extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry? padding;

  const AppSettingSectionTitle({
    super.key,
    required this.title,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: context.colorScheme.onSurfaceVariant.textTheme.overlineStyle
            .copyWith(
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
