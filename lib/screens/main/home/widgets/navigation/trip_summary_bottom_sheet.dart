import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';

/// Modal BottomSheet hiển thị thống kê chuyến đi sau khi đến đích hoặc kết thúc hành trình
class TripSummaryBottomSheet extends StatelessWidget {
  final TripSummary summary;
  final VoidCallback onDone;

  const TripSummaryBottomSheet({
    super.key,
    required this.summary,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final themeColors = context.themeColors;

    final title = summary.hasArrived
        ? tr(LocaleKeys.routing_trip_completed_title)
        : tr(LocaleKeys.routing_trip_stopped_title);
    final destination = summary.destinationName?.isNotEmpty == true
        ? summary.destinationName!
        : tr(LocaleKeys.routing_destination_fallback);

    final durationStr = RouteFormatHelper.formatTripDuration(summary.duration);
    final distanceStr = RouteFormatHelper.formatDistance(summary.distanceMeters);
    final avgSpeedStr =
        '${summary.avgSpeedKmh.toStringAsFixed(1)} ${tr(LocaleKeys.routing_speed_kmh)}';
    final topSpeedStr =
        '${summary.topSpeedKmh.toStringAsFixed(1)} ${tr(LocaleKeys.routing_speed_kmh)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // 2. Header Icon & Status
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: (summary.hasArrived
                            ? themeColors.statsSuccess
                            : colorScheme.primary)
                        .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    summary.hasArrived
                        ? Icons.emoji_events_rounded
                        : Icons.check_circle_rounded,
                    color: summary.hasArrived
                        ? themeColors.statsSuccess
                        : colorScheme.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: colorScheme.onSurface.textTheme.boldStyle.copyWith(
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        destination,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: colorScheme.onSurfaceVariant.textTheme.mediumStyle.copyWith(
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 3. Stat Cards 2x2 Grid
            Row(
              children: [
                Expanded(
                  child: AppMetricCard(
                    icon: Icons.timer_outlined,
                    label: tr(LocaleKeys.routing_trip_duration),
                    value: durationStr,
                    iconColor: themeColors.statsBlue,
                    backgroundColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppMetricCard(
                    icon: Icons.straighten_rounded,
                    label: tr(LocaleKeys.routing_trip_distance),
                    value: distanceStr,
                    iconColor: themeColors.statsOrange,
                    backgroundColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppMetricCard(
                    icon: Icons.speed_rounded,
                    label: tr(LocaleKeys.routing_avg_speed),
                    value: avgSpeedStr,
                    iconColor: themeColors.statsSuccess,
                    backgroundColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppMetricCard(
                    icon: Icons.bolt_rounded,
                    label: tr(LocaleKeys.routing_max_speed),
                    value: topSpeedStr,
                    iconColor: themeColors.statsPink,
                    backgroundColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 4. Action Button "Xong"
            ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                tr(LocaleKeys.routing_done),
                style: colorScheme.onPrimary.textTheme.boldStyle.copyWith(
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
