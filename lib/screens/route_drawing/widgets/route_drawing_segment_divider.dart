import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:s_map/generated/locale_keys.g.dart';

/// Đường nối giữa 2 điểm waypoint phong cách Google Maps:
/// - Bên trái: Dải 3 chấm dọc (⋮) thẳng hàng với icon điểm.
/// - Ở giữa: Đường kẻ mỏng ngang.
/// - Bên phải: Nút tròn máy bay (✈) build chuẩn pattern Material + InkWell (40x40).
class RouteDrawingSegmentDivider extends StatelessWidget {
  final int segmentIndex;
  final bool isStraightLine;
  final VoidCallback onToggle;

  const RouteDrawingSegmentDivider({
    super.key,
    required this.segmentIndex,
    required this.isStraightLine,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 0.5),
      child: Row(
        children: [
          // Khoảng trống bù cho Drag Handle (22 + 4 = 26px) giúp 3 chấm thẳng hàng tuyệt đối với icon điểm
          const SizedBox(width: 26),

          // 1. Dải 3 chấm dọc nối thẳng hàng với icon waypoint
          SizedBox(
            width: 24,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  3,
                  (index) => Container(
                    width: 2.2,
                    height: 2.2,
                    margin: const EdgeInsets.symmetric(vertical: 1.2),
                    decoration: BoxDecoration(
                      color: isStraightLine
                          ? activeColor
                          : colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // 2. Đường kẻ phân cách ngang
          Expanded(
            child: Container(
              height: 0.6,
              color: colorScheme.outline.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(width: 4),

          // 3. Nút tròn máy bay ✈ chuẩn pattern IconButton / Material + InkWell
          Tooltip(
            message: isStraightLine
                ? tr(LocaleKeys.route_drawing_ui_straight_line)
                : tr(LocaleKeys.route_drawing_ui_follow_roads),
            child: Material(
              color: isStraightLine
                  ? activeColor.withValues(alpha: 0.18)
                  : colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.35),
              shape: CircleBorder(
                side: BorderSide(
                  color: isStraightLine
                      ? activeColor
                      : colorScheme.outline.withValues(alpha: 0.25),
                  width: isStraightLine ? 1.4 : 0.8,
                ),
              ),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  HapticFeedback.lightImpact();
                  onToggle();
                },
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: Icon(
                      Icons.linear_scale_rounded,
                      size: 18,
                      color: isStraightLine
                          ? activeColor
                          : colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
