import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/generated/locale_keys.g.dart';

/// Nút hành động Bắt đầu điều hướng & Vẽ lộ trình tùy chỉnh trong RoutePreviewBottomSheet
class RoutePreviewActionButtons extends StatelessWidget {
  final VoidCallback? onStartNavigation;
  final VoidCallback? onCustomRoute;

  const RoutePreviewActionButtons({
    super.key,
    this.onStartNavigation,
    this.onCustomRoute,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Row(
      children: [
        Expanded(
          flex: 1,
          child: ElevatedButton.icon(
            onPressed: onStartNavigation,
            icon: Icon(
              Icons.navigation_rounded,
              size: 20,
              color: colorScheme.onPrimary,
            ),
            label: Text(
              tr(LocaleKeys.routing_start_navigation),
              style: colorScheme.onPrimary.textTheme.boldStyle.copyWith(
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
        if (onCustomRoute != null) ...[
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: OutlinedButton.icon(
              onPressed: onCustomRoute,
              icon: Icon(
                Icons.gesture_rounded,
                size: 18,
                color: colorScheme.primary,
              ),
              label: Text(
                tr(LocaleKeys.route_drawing_ui_custom_route_drawing),
                style: colorScheme.primary.textTheme.semiBoldStyle.copyWith(
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.primary,
                side: BorderSide(
                  color: colorScheme.primary.withAlpha(120),
                  width: 1.2,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
