import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';

enum AppMetricCardLayout {
  vertical,
  horizontal,
}

class AppMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final String? subtitle;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final AppMetricCardLayout layout;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const AppMetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    this.subtitle,
    this.iconColor,
    this.iconBackgroundColor,
    this.layout = AppMetricCardLayout.vertical,
    this.backgroundColor,
    this.padding,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final effectiveIconColor = iconColor ?? colorScheme.primary;
    final effectiveIconBg = iconBackgroundColor ??
        effectiveIconColor.withValues(alpha: 0.12);
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(14);
    final effectiveBg = backgroundColor ?? colorScheme.surface;

    final child = layout == AppMetricCardLayout.horizontal
        ? _buildHorizontalLayout(
            context,
            colorScheme,
            effectiveIconColor,
            effectiveIconBg,
          )
        : _buildVerticalLayout(
            context,
            colorScheme,
            effectiveIconColor,
            effectiveIconBg,
          );

    return Container(
      padding: padding ??
          (layout == AppMetricCardLayout.horizontal
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
              : const EdgeInsets.all(12)),
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: effectiveBorderRadius,
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.12),
          width: 0.8,
        ),
      ),
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: effectiveBorderRadius,
              child: child,
            )
          : child,
    );
  }

  Widget _buildVerticalLayout(
    BuildContext context,
    ColorScheme colorScheme,
    Color effIconColor,
    Color effIconBg,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: effIconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: effIconColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: colorScheme.onSurfaceVariant.textTheme.captionStyle
                    .copyWith(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                value,
                style: colorScheme.onSurface.textTheme.boldStyle
                    .copyWith(fontSize: 18),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 3),
              Text(
                unit!,
                style: colorScheme.onSurfaceVariant.textTheme.semiBoldStyle
                    .copyWith(fontSize: 11),
              ),
            ],
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: effIconColor.textTheme.captionStyle.copyWith(fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildHorizontalLayout(
    BuildContext context,
    ColorScheme colorScheme,
    Color effIconColor,
    Color effIconBg,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: effIconBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: effIconColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: colorScheme.onSurfaceVariant.textTheme.captionStyle
                    .copyWith(fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      style: colorScheme.onSurface.textTheme.boldStyle
                          .copyWith(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (unit != null) ...[
                    const SizedBox(width: 2),
                    Text(
                      unit!,
                      style: colorScheme.onSurfaceVariant.textTheme.semiBoldStyle
                          .copyWith(fontSize: 10),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
