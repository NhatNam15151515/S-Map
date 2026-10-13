import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';
import 'route_drawing_waypoint_icon.dart';
import 'route_drawing_waypoint_list.dart';

/// Card Menu hiển thị danh sách Waypoints phong cách Google Maps:
/// - Khi chưa có điểm: Tận dụng trực tiếp MapSearchBar của màn hình chính.
/// - Khi đã có điểm: Card chứa các điểm xuất phát, điểm dừng và điểm đến.
/// - Giữa các điểm có nút đường thẳng / chim bay căn giữa.
/// - Dưới cùng là nút "+" để tìm kiếm và thêm điểm dừng vào lộ trình.
/// - Dùng Listener(HitTestBehavior.opaque) chặn touch xuyên map mà không nuốt gesture của con.
class RouteDrawingWaypointPanel extends StatefulWidget {
  final double topPadding;
  final List<SnappedRoadPoint> points;
  final List<RouteResult> segments;
  final VoidCallback onSavedRoutesPressed;
  final VoidCallback onSearchDestinationPressed;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(int index) onRemovePoint;
  final void Function(int segmentIndex) onToggleSegmentStraightLine;
  final bool showStraightLineToggles;
  final Widget? searchBarTrailing;

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
    this.showStraightLineToggles = true,
    this.searchBarTrailing,
  });

  @override
  State<RouteDrawingWaypointPanel> createState() =>
      _RouteDrawingWaypointPanelState();
}

class _RouteDrawingWaypointPanelState extends State<RouteDrawingWaypointPanel> {
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Positioned(
      top: widget.topPadding + 6,
      left: 16,
      right: 16,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            onPanStart: (_) {},
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) {}, // Chặn touch xuyên xuống Native MapView
              child: widget.points.isEmpty
                ? MapSearchBar(
                    key: const Key('route_drawing_search_destination_button'),
                    showBackButton: false,
                    onTap: widget.onSearchDestinationPressed,
                    trailing: widget.searchBarTrailing,
                  )
                : Container(
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
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOutCubic,
                      child: _isCollapsed && widget.points.length >= 2
                          ? _buildCollapsedSummary(context, colorScheme)
                          : RouteDrawingWaypointList(
                              points: widget.points,
                              segments: widget.segments,
                              onReorder: widget.onReorder,
                              onRemovePoint: widget.onRemovePoint,
                              onToggleSegmentStraightLine:
                                  widget.onToggleSegmentStraightLine,
                              onAddDestinationPressed:
                                  widget.onSearchDestinationPressed,
                              onSavedRoutesPressed: widget.onSavedRoutesPressed,
                              showStraightLineToggles:
                                  widget.showStraightLineToggles,
                              onCollapse: widget.points.length >= 2
                                  ? () {
                                      HapticFeedback.lightImpact();
                                      setState(() => _isCollapsed = true);
                                    }
                                  : null,
                            ),
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }

  /// Thanh tóm tắt siêu nhỏ gọn khi Top Bar được thu gọn
  Widget _buildCollapsedSummary(BuildContext context, ColorScheme colorScheme) {
    final points = widget.points;
    final origin = points.first.displayName.trim().isNotEmpty
        ? points.first.displayName.trim()
        : points.first.streetName.trim().isNotEmpty
        ? points.first.streetName.trim()
        : tr(LocaleKeys.routing_my_location);
    final destination = points.last.displayName.trim().isNotEmpty
        ? points.last.displayName.trim()
        : points.last.streetName.trim().isNotEmpty
        ? points.last.streetName.trim()
        : '${points.last.snappedLat.toStringAsFixed(4)}, ${points.last.snappedLon.toStringAsFixed(4)}';

    return InkWell(
      key: const Key('route_drawing_expand_waypoints_button'),
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _isCollapsed = false);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 7.0),
        child: Row(
          children: [
            const RouteDrawingWaypointIcon(index: 0, totalCount: 2),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$origin → $destination (${points.length} ${tr(LocaleKeys.route_drawing_ui_waypoints_label).toLowerCase()})',
                style: colorScheme.onSurface.textTheme.semiBoldStyle.copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: tr(LocaleKeys.route_drawing_ui_expand_waypoints),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
