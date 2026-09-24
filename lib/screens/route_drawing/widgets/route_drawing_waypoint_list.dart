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

  const RouteDrawingWaypointList({
    super.key,
    required this.points,
    required this.segments,
    required this.onReorder,
    required this.onRemovePoint,
    required this.onToggleSegmentStraightLine,
    required this.onAddDestinationPressed,
    required this.onSavedRoutesPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pointsCount = points.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Danh sách các điểm dừng cuộn mượt mà
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.35,
          ),
          child: Theme(
            data: Theme.of(context).copyWith(canvasColor: Colors.transparent),
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: pointsCount,
              // ignore: deprecated_member_use
              onReorder: onReorder,
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

        // 2. Đường kẻ phân cách trước nút thêm điểm
        Divider(
          height: 1,
          thickness: 0.6,
          color: colorScheme.outline.withValues(alpha: 0.15),
        ),

        // 3. Nút "+" lớn ở đáy card (theo đúng hình khoanh đỏ của anh Nam)
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('route_drawing_search_destination_button'),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
            onTap: onAddDestinationPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_rounded,
                    size: 22,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tr(LocaleKeys.route_drawing_ui_add_destination),
                    style: TextStyle(
                      fontSize: 13.5,
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
    );
  }
}
