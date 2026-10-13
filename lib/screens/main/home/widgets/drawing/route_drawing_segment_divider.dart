import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:s_map/generated/locale_keys.g.dart';

/// Đường nối giữa 2 điểm waypoint phong cách Google Maps:
/// - Đường kẻ mỏng ngang tối giản, không còn 3 chấm thừa.
/// - Bên phải: Nút đường chim bay nhỏ gọn (20x20) để khoảng cách giữa 2 dòng là thấp nhất.
class RouteDrawingSegmentDivider extends StatelessWidget {
  final int segmentIndex;
  final bool isStraightLine;
  final VoidCallback onToggle;
  final bool showStraightLineToggle;

  const RouteDrawingSegmentDivider({
    super.key,
    required this.segmentIndex,
    required this.isStraightLine,
    required this.onToggle,
    this.showStraightLineToggle = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = colorScheme.primary;

    if (!showStraightLineToggle) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Container(
          height: 0.5,
          color: colorScheme.outline.withValues(alpha: 0.12),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SizedBox(
        height: 18,
        child: Row(
          children: [
            // 1. Đường kẻ phân cách bên trái
            Expanded(
              child: Container(
                height: 0.5,
                color: colorScheme.outline.withValues(alpha: 0.12),
              ),
            ),
            const SizedBox(width: 8),

            // 2. Nút chim bay nhỏ gọn (20x20) ở chính giữa
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
                        : colorScheme.outline.withValues(alpha: 0.2),
                    width: isStraightLine ? 1.0 : 0.6,
                  ),
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onToggle();
                  },
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: Center(
                      child: Icon(
                        Icons.linear_scale_rounded,
                        size: 12,
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
            const SizedBox(width: 8),

            // 3. Đường kẻ phân cách bên phải
            Expanded(
              child: Container(
                height: 0.5,
                color: colorScheme.outline.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
