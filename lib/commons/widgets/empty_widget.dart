import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';

class EmptyWidget extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onRefresh;

  const EmptyWidget({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.primary.withAlpha(35),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon ?? Icons.inbox_rounded,
              size: 48,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          if (title != null)
            Text(
              title!,
              style: colorScheme.onSurface.textTheme.subTitleStyle.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: colorScheme.onSurfaceVariant
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
              padding: const EdgeInsets.only(top: 20),
              child: OutlinedButton.icon(
                onPressed: onRefresh,
                icon: Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: colorScheme.primary,
                ),
                label: Text(
                  tr('cancel'),
                  style: colorScheme.primary.textTheme.boldStyle.copyWith(
                    fontSize: 14,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  side: BorderSide(color: colorScheme.primary, width: 1),
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
    );
  }
}
