import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';

/// Pure Dumb Widget hiển thị thẻ thông tin 1 lộ trình tùy biến đã lưu.
class SavedRouteCard extends StatelessWidget {
  final CustomRouteModel route;
  final VoidCallback onViewDrawing;
  final VoidCallback onStartNavigation;
  final VoidCallback onDelete;

  const SavedRouteCard({
    super.key,
    required this.route,
    required this.onViewDrawing,
    required this.onStartNavigation,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final distanceStr = RouteFormatHelper.formatDistance(route.totalDistance);
    final durationStr = RouteFormatHelper.formatDuration(route.totalTime);
    final waypointsCountStr = tr(
      LocaleKeys.route_drawing_ui_waypoints_count,
      args: [route.waypoints.length.toString()],
    );

    return Container(
      key: Key('saved_route_card_${route.id}'),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withAlpha(50),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.alt_route_rounded,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route.name,
                        style: colorScheme.onSurface.textTheme.boldStyle.copyWith(
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$distanceStr • $durationStr • $waypointsCountStr',
                        style: colorScheme.onSurfaceVariant.textTheme.textStyle.copyWith(
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: Key('delete_saved_route_${route.id}'),
                  icon: Icon(
                    Icons.bookmark_remove_rounded,
                    size: 20,
                    color: colorScheme.error,
                  ),
                  tooltip: tr(LocaleKeys.route_drawing_ui_delete_route),
                  onPressed: onDelete,
                ),
              ],
            ),
            if (route.description != null && route.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                route.description!,
                style: colorScheme.onSurfaceVariant.textTheme.textStyle.copyWith(
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppButton.outlined(
                    key: Key('view_drawing_btn_${route.id}'),
                    text: tr(LocaleKeys.route_drawing_ui_view_drawing),
                    icon: Icon(
                      Icons.edit_rounded,
                      size: 16,
                      color: colorScheme.onSurface,
                    ),
                    textColor: colorScheme.onSurface,
                    borderColor: colorScheme.outline.withAlpha(80),
                    height: 40,
                    width: null,
                    borderRadius: 10,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    onPressed: onViewDrawing,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton.primary(
                    key: Key('navigation_btn_${route.id}'),
                    text: tr(LocaleKeys.navigation),
                    icon: const Icon(
                      Icons.navigation_rounded,
                      size: 16,
                    ),
                    height: 40,
                    width: null,
                    borderRadius: 10,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    onPressed: onStartNavigation,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
