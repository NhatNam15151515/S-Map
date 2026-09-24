import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';
import 'route_drawing_point_icon.dart';

/// Dòng hiển thị 1 điểm waypoint trong Card Menu Google Maps:
/// - Bên trái: Icon 2 gạch drag handle (≡) để kéo thả, sau đó đến Icon điểm.
/// - Ở giữa: Tên địa điểm rõ ràng.
/// - Bên phải: Menu 3 chấm (dòng đầu) hoặc Nút xóa (các dòng tiếp theo).
class RouteDrawingWaypointItem extends StatelessWidget {
  final int index;
  final int totalCount;
  final SnappedRoadPoint point;
  final VoidCallback onRemove;
  final VoidCallback? onSavedRoutesPressed;

  const RouteDrawingWaypointItem({
    super.key,
    required this.index,
    required this.totalCount,
    required this.point,
    required this.onRemove,
    this.onSavedRoutesPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final displayName = point.streetName.trim().isNotEmpty
        ? point.streetName.trim()
        : (index == 0
            ? tr(LocaleKeys.routing_my_location)
            : '${point.snappedLat.toStringAsFixed(4)}, ${point.snappedLon.toStringAsFixed(4)}');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 3.0),
      child: Row(
        children: [
          // 1. Icon 2 gạch kéo thả (Drag Handle) đưa ra đầu bên trái
          ReorderableDragStartListener(
            index: index,
            child: SizedBox(
              width: 22,
              height: 32,
              child: Center(
                child: Icon(
                  Icons.drag_handle_rounded,
                  size: 18,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // 2. Icon điểm dừng chuẩn Google Maps
          SizedBox(
            width: 24,
            child: Center(
              child: RouteDrawingPointIcon(
                index: index,
                totalCount: totalCount,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // 3. Tên địa điểm
          Expanded(
            child: Text(
              displayName,
              style: colorScheme.onSurface.textTheme.semiBoldStyle.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // 4. Actions bên phải: 3 chấm ở dòng đầu, nút xóa ở dòng sau
          if (index == 0)
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                size: 20,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              splashRadius: 18,
              onSelected: (value) {
                if (value == 'save' && onSavedRoutesPressed != null) {
                  onSavedRoutesPressed!();
                } else if (value == 'delete') {
                  onRemove();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'save',
                  child: Row(
                    children: [
                      Icon(Icons.bookmark_outline_rounded,
                          size: 18, color: colorScheme.primary),
                      const SizedBox(width: 10),
                      Text(
                        tr(LocaleKeys.route_drawing_ui_saved_routes_title),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 18, color: colorScheme.error),
                      const SizedBox(width: 10),
                      Text(
                        tr(LocaleKeys.route_drawing_ui_delete_waypoint_tooltip),
                        style: TextStyle(
                            fontSize: 13, color: colorScheme.error),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                size: 17,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              splashRadius: 16,
              tooltip: tr(LocaleKeys.route_drawing_ui_delete_waypoint_tooltip),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}
