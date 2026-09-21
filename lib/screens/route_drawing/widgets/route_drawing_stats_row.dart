import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/route_format_helper.dart';
import 'package:s_map/generated/locale_keys.g.dart';

/// Widget hiển thị thống kê tóm tắt route: khoảng cách, thời gian, số waypoints.
class RouteDrawingStatsRow extends StatelessWidget {
  final double distanceMeters;
  final int durationMs;
  final int pointCount;

  const RouteDrawingStatsRow({
    super.key,
    required this.distanceMeters,
    required this.durationMs,
    required this.pointCount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final formattedDistance = RouteFormatHelper.formatDistance(distanceMeters);
    final formattedDuration = RouteFormatHelper.formatDuration(durationMs);

    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            colorScheme,
            icon: HeroIcons.mapPin,
            value: formattedDistance,
            label: tr(LocaleKeys.routing_trip_distance),
          ),
        ),
        _buildDivider(colorScheme),
        Expanded(
          child: _buildStatItem(
            colorScheme,
            icon: HeroIcons.clock,
            value: formattedDuration,
            label: tr(LocaleKeys.routing_trip_duration),
          ),
        ),
        _buildDivider(colorScheme),
        Expanded(
          child: _buildStatItem(
            colorScheme,
            icon: HeroIcons.flag,
            value: pointCount.toString(),
            label: tr(LocaleKeys.route_drawing_ui_waypoints_label),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(ColorScheme colorScheme) {
    return Container(
      width: 1,
      height: 32,
      color: colorScheme.outline.withValues(alpha: 0.2),
    );
  }

  Widget _buildStatItem(
    ColorScheme colorScheme, {
    required HeroIcons icon,
    required String value,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HeroIcon(icon, size: 16, color: colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              value,
              style: colorScheme.onSurface.textTheme.boldStyle.copyWith(
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: colorScheme.onSurfaceVariant.textTheme.textStyle.copyWith(
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
