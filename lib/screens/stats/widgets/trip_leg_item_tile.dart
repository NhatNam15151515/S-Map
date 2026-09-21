import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/route_format_helper.dart';
import 'package:s_map/commons/utils/trip_format_helper.dart';
import 'package:s_map/commons/utils/trip_leg_extractor.dart';
import 'package:s_map/generated/locale_keys.g.dart';

/// Widget hiển thị thông tin 1 chặng đường (leg) trong danh sách chi tiết chuyến đi.
///
/// Bao gồm: badge số thứ tự, tên đường, quãng đường, thời gian,
/// vận tốc trung bình và vận tốc tối đa.
class TripLegItemTile extends StatelessWidget {
  final TripLegItem leg;

  const TripLegItemTile({
    super.key,
    required this.leg,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final durationStr = RouteFormatHelper.formatTripDuration(leg.duration);
    final distanceStr = leg.distanceKm >= 1.0
        ? '${leg.distanceKm.toStringAsFixed(1)} km'
        : '${leg.distanceMeters.round()} m';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildIndexBadge(colorScheme),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitle(colorScheme),
              const SizedBox(height: 6),
              _buildStatsWrap(context, colorScheme, distanceStr, durationStr),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIndexBadge(ColorScheme colorScheme) {
    return Container(
      width: 22,
      height: 22,
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          '${leg.index}',
          style: colorScheme.onSurfaceVariant.textTheme.boldStyle.copyWith(
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(ColorScheme colorScheme) {
    return Text(
      leg.title,
      style: colorScheme.onSurface.textTheme.semiBoldStyle.copyWith(
        fontSize: 13,
        height: 1.3,
      ),
      softWrap: true,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildStatsWrap(
    BuildContext context,
    ColorScheme colorScheme,
    String distanceStr,
    String durationStr,
  ) {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildStatChip(
          icon: Icons.straighten_rounded,
          iconColor: colorScheme.primary,
          text: distanceStr,
          textColor: colorScheme.primary,
          colorScheme: colorScheme,
          isBold: true,
        ),
        _buildStatChip(
          icon: Icons.timer_outlined,
          iconColor: colorScheme.onSurfaceVariant,
          text: durationStr,
          textColor: colorScheme.onSurfaceVariant,
          colorScheme: colorScheme,
        ),
        _buildStatChip(
          icon: Icons.speed_rounded,
          iconColor: colorScheme.onSurfaceVariant,
          text:
              '${TripFormatHelper.safeTr(LocaleKeys.stats_dashboard_detail_street_avg_speed, 'TB')}: ${leg.avgSpeedKmh.toStringAsFixed(0)} km/h',
          textColor: colorScheme.onSurfaceVariant,
          colorScheme: colorScheme,
          isCaption: true,
        ),
        _buildStatChip(
          icon: Icons.bolt_rounded,
          iconColor: context.themeColors.statsOrange,
          text:
              '${TripFormatHelper.safeTr(LocaleKeys.stats_dashboard_detail_street_max_speed, 'Tối đa')}: ${leg.topSpeedKmh.toStringAsFixed(0)} km/h',
          textColor: colorScheme.onSurfaceVariant,
          colorScheme: colorScheme,
          isCaption: true,
          iconSize: 14,
        ),
      ],
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required Color iconColor,
    required String text,
    required Color textColor,
    required ColorScheme colorScheme,
    bool isBold = false,
    bool isCaption = false,
    double iconSize = 13,
  }) {
    final style = isCaption
        ? colorScheme.onSurfaceVariant.textTheme.captionStyle
        : isBold
            ? colorScheme.primary.textTheme.semiBoldStyle
            : colorScheme.onSurfaceVariant.textTheme.mediumStyle;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: iconColor),
        const SizedBox(width: 3),
        Text(
          text,
          style: style.copyWith(fontSize: 11),
        ),
      ],
    );
  }
}
