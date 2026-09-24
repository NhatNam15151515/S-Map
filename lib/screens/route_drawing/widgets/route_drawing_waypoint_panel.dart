import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';
import 'route_drawing_point_icon.dart';
import 'route_drawing_waypoint_list.dart';

/// Card Menu hiển thị danh sách Waypoints phong cách Google Maps:
/// - Bên trái: Nút Back tròn nổi quay lại màn hình trước.
/// - Bên phải: Card chứa các điểm xuất phát, điểm dừng và điểm đến.
/// - Giữa các điểm có dải chấm dọc ⋮ và nút máy bay ✈ bên phải để toggle đường chim bay.
/// - Đáy Card là nút "+" để tìm kiếm và thêm điểm dừng vào lộ trình.
/// - Dùng Listener(HitTestBehavior.opaque) chặn touch xuyên map mà không nuốt gesture của con.
class RouteDrawingWaypointPanel extends StatelessWidget {
  final double topPadding;
  final List<SnappedRoadPoint> points;
  final List<RouteResult> segments;
  final VoidCallback onSavedRoutesPressed;
  final VoidCallback onSearchDestinationPressed;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(int index) onRemovePoint;
  final void Function(int segmentIndex) onToggleSegmentStraightLine;

  const RouteDrawingWaypointPanel({
    super.key,
    required this.topPadding,
    required this.points,
    required this.segments,
    required this.onSavedRoutesPressed,
    required this.onSearchDestinationPressed,
    required this.onReorder,
    required this.onRemovePoint,
    required this.onToggleSegmentStraightLine,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Positioned(
      top: topPadding + 6,
      left: 12,
      right: 12,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {}, // Chặn touch xuyên xuống Native MapView
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Nút Back tròn nổi phong cách Google Maps
            Material(
              color: colorScheme.surface,
              elevation: 3,
              shadowColor: colorScheme.shadow.withValues(alpha: 0.2),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).maybePop(),
                child: const SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(Icons.arrow_back_rounded, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // 2. Card danh sách Waypoints Google Maps
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.15),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.16),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: points.isEmpty
                    ? _buildEmptyState(context, colorScheme)
                    : RouteDrawingWaypointList(
                        points: points,
                        segments: segments,
                        onReorder: onReorder,
                        onRemovePoint: onRemovePoint,
                        onToggleSegmentStraightLine:
                            onToggleSegmentStraightLine,
                        onAddDestinationPressed: onSearchDestinationPressed,
                        onSavedRoutesPressed: onSavedRoutesPressed,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      child: InkWell(
        key: const Key('route_drawing_search_destination_button'),
        borderRadius: BorderRadius.circular(12),
        onTap: onSearchDestinationPressed,
        child: Row(
          children: [
            const RouteDrawingPointIcon(index: 0, totalCount: 1),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr(LocaleKeys.route_drawing_ui_search_destination_tooltip),
                style: colorScheme.onSurfaceVariant.textTheme.regularStyle
                    .copyWith(fontSize: 13.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.search_rounded,
              size: 20,
              color: colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
