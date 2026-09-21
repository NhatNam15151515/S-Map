import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/generated/locale_keys.g.dart';

/// Widget hiển thị hướng dẫn khi chưa có hoặc mới có 1 điểm trên route.
///
/// - `pointCount == 0`: Hướng dẫn "Chạm để thêm điểm đầu tiên"
/// - `pointCount == 1`: Hướng dẫn "Thêm điểm tiếp theo" + đếm waypoints
class RouteDrawingEmptyPrompt extends StatelessWidget {
  final int pointCount;

  const RouteDrawingEmptyPrompt({
    super.key,
    required this.pointCount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    if (pointCount == 0) {
      return _buildZeroPointPrompt(colorScheme);
    }
    return _buildOnePointPrompt(colorScheme);
  }

  Widget _buildZeroPointPrompt(ColorScheme colorScheme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: HeroIcon(
            HeroIcons.cursorArrowRays,
            size: 24,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            tr(LocaleKeys.route_drawing_ui_tap_prompt),
            style: colorScheme.onSurface.textTheme.mediumStyle.copyWith(
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOnePointPrompt(ColorScheme colorScheme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: HeroIcon(
            HeroIcons.mapPin,
            size: 24,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr(LocaleKeys.route_drawing_ui_add_next_prompt),
                style: colorScheme.onSurface.textTheme.semiBoldStyle.copyWith(
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tr(LocaleKeys.route_drawing_ui_waypoints_count, args: ['1']),
                style: colorScheme.onSurfaceVariant.textTheme.textStyle.copyWith(
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
