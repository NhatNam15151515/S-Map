import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class EmptyWidget extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onRefresh;
  final String? actionLabel;
  final Color? textColor;
  final Color? iconColor;

  const EmptyWidget({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.onRefresh,
    this.actionLabel,
    this.textColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final resolvedIconColor = iconColor ?? colorScheme.primary;
    final resolvedActionColor = textColor ?? colorScheme.primary;

    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: resolvedIconColor.withAlpha(35),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? Icons.inbox_rounded,
                size: 48,
                color: resolvedIconColor,
              ),
            ),
            const SizedBox(height: 16),
            if (title != null)
              Text(
                title!,
                style: (textColor ?? colorScheme.onSurface)
                    .textTheme
                    .subTitleStyle
                    .copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: (textColor ?? colorScheme.onSurfaceVariant)
                    .textTheme
                    .textStyle
                    .copyWith(
                      fontSize: 14,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRefresh != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: OutlinedButton.icon(
                  onPressed: onRefresh,
                  icon: Icon(
                    Icons.refresh_rounded,
                    size: 18,
                    color: resolvedActionColor,
                  ),
                  label: Text(
                    actionLabel ?? tr(LocaleKeys.retry),
                    style: resolvedActionColor.textTheme.boldStyle.copyWith(
                      fontSize: 14,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: resolvedActionColor,
                    side: BorderSide(color: resolvedActionColor, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
