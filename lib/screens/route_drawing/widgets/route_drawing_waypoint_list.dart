import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';
import 'route_drawing_segment_divider.dart';
import 'route_drawing_waypoint_item.dart';

/// Danh sách các điểm dừng (Waypoints) hiển thị theo trục dọc phong cách Google Maps:
/// - Kéo thả sắp xếp lại thứ tự điểm.
/// - Segment divider giữa 2 điểm với nút máy bay (✈) bên phải.
/// - Nút "+" lớn ở đáy card để thêm địa điểm.
class RouteDrawingWaypointList extends StatelessWidget {
  final List<SnappedRoadPoint> points;
  final List<RouteResult> segments;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(int index) onRemovePoint;
  final void Function(int segmentIndex) onToggleSegmentStraightLine;
  final VoidCallback onAddDestinationPressed;
  final VoidCallback onSavedRoutesPressed;
  final VoidCallback? onCollapse;

  const RouteDrawingWaypointList({
    super.key,
    required this.points,
    required this.segments,
    required this.onReorder,
    required this.onRemovePoint,
    required this.onToggleSegmentStraightLine,
    required this.onAddDestinationPressed,
    required this.onSavedRoutesPressed,
    this.onCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pointsCount = points.length;
    final screenHeight = MediaQuery.sizeOf(context).height;
    // Giới hạn chiều cao danh sách: vừa vặn 3 điểm kèm nút thêm điểm (210px), cuộn mượt mà khi từ 4 điểm trở lên (tối đa 260px)
    final maxListHeight = (screenHeight * 0.35).clamp(210.0, 260.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Danh sách các điểm dừng cuộn mượt mà
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxListHeight,
          ),
          child: Theme(
            data: Theme.of(context).copyWith(canvasColor: Colors.transparent),
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: pointsCount,
              // ignore: deprecated_member_use
              onReorder: onReorder,
              footer: Column(
                key: const ValueKey('route_drawing_add_destination_footer'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Divider(
                    height: 1,
                    thickness: 0.6,
                    color: colorScheme.outline.withValues(alpha: 0.15),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: const Key('route_drawing_search_destination_button'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: onAddDestinationPressed,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              size: 19,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              tr(LocaleKeys.route_drawing_ui_add_destination),
                              style: TextStyle(
                                fontSize: 13.0,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              itemBuilder: (context, index) {
                final pt = points[index];
                final isStraight = index < segments.length
                    ? segments[index].isStraightLine
                    : false;

                return Column(
                  key: ValueKey(
                      'wp_${index}_${pt.snappedLat}_${pt.snappedLon}'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RouteDrawingWaypointItem(
                      index: index,
                      totalCount: pointsCount,
                      point: pt,
                      onRemove: () => onRemovePoint(index),
                      onSavedRoutesPressed: onSavedRoutesPressed,
                    ),
                    if (index < pointsCount - 1)
                      RouteDrawingSegmentDivider(
                        segmentIndex: index,
                        isStraightLine: isStraight,
                        onToggle: () => onToggleSegmentStraightLine(index),
                      ),
                  ],
                );
              },
            ),
          ),
        ),

        // 2. Handle thu gọn ở chính giữa mép dưới card
        if (onCollapse != null)
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('route_drawing_collapse_waypoints_button'),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
              onTap: onCollapse,
              child: Tooltip(
                message: tr(LocaleKeys.route_drawing_ui_collapse_waypoints),
                child: SizedBox(
                  width: double.infinity,
                  height: 18,
                  child: Center(
                    child: Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 20,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
