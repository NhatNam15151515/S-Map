import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class RouteDrawingBottomCard extends StatelessWidget {
  final int pointCount;
  final double distanceMeters;
  final int durationMs;
  final bool isLoading;
  final VoidCallback onSavePressed;
  final VoidCallback onNavigatePressed;

  const RouteDrawingBottomCard({
    super.key,
    required this.pointCount,
    required this.distanceMeters,
    required this.durationMs,
    required this.isLoading,
    required this.onSavePressed,
    required this.onNavigatePressed,
  });

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomPadding + 16,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withAlpha(25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: AppColors.sMapLightTeal,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.sMapTeal),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: _buildContent(context, style),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppStyle style) {
    if (pointCount == 0) {
      return Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: AppColors.sMapLightTeal,
              shape: BoxShape.circle,
            ),
            child: const HeroIcon(
              HeroIcons.cursorArrowRays,
              size: 24,
              color: AppColors.sMapTeal,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              tr(LocaleKeys.route_drawing_ui_tap_prompt),
              style: style.blackTextColor.textTheme.mediumStyle.copyWith(
                fontSize: 14,
                color: AppColors.grimReaper,
              ),
            ),
          ),
        ],
      );
    }

    if (pointCount == 1) {
      return Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.paleRobinEggBlue.withAlpha(50),
              shape: BoxShape.circle,
            ),
            child: const HeroIcon(
              HeroIcons.mapPin,
              size: 24,
              color: AppColors.sMapTeal,
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
                  style: style.blackTextColor.textTheme.semiBoldStyle.copyWith(
                    fontSize: 14,
                    color: AppColors.grimReaper,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tr(LocaleKeys.route_drawing_ui_waypoints_count, args: ['1']),
                  style: style.blackTextColor.textTheme.textStyle.copyWith(
                    fontSize: 12,
                    color: AppColors.sonicSilver,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final distanceKm = distanceMeters / 1000.0;
    final durationMinutes = (durationMs / 60000.0).round();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Stats Summary Row
        Row(
          children: [
            Expanded(
              child: _buildStatItem(
                context,
                style,
                icon: HeroIcons.mapPin,
                value: '${distanceKm.toStringAsFixed(1)} km',
                label: tr(LocaleKeys.routing_trip_distance),
              ),
            ),
            Container(width: 1, height: 32, color: AppColors.plaster),
            Expanded(
              child: _buildStatItem(
                context,
                style,
                icon: HeroIcons.clock,
                value: '$durationMinutes ${tr(LocaleKeys.routing_unit_minute)}',
                label: tr(LocaleKeys.routing_trip_duration),
              ),
            ),
            Container(width: 1, height: 32, color: AppColors.plaster),
            Expanded(
              child: _buildStatItem(
                context,
                style,
                icon: HeroIcons.flag,
                value: pointCount.toString(),
                label: tr(LocaleKeys.route_drawing_ui_waypoints_label),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Action Buttons Row
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('route_drawing_save_button'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: AppColors.sMapTeal, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const HeroIcon(
                  HeroIcons.bookmark,
                  size: 18,
                  color: AppColors.sMapTeal,
                ),
                label: Text(
                  tr(LocaleKeys.route_drawing_ui_save_route),
                  style: style.blackTextColor.textTheme.semiBoldStyle.copyWith(
                    fontSize: 14,
                    color: AppColors.sMapTeal,
                  ),
                ),
                onPressed: onSavePressed,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                key: const Key('route_drawing_navigate_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sMapTeal,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(
                  Icons.navigation_rounded,
                  size: 18,
                  color: AppColors.white,
                ),
                label: Text(
                  tr(LocaleKeys.route_drawing_ui_start_navigation),
                  style: style.blackTextColor.textTheme.boldStyle.copyWith(
                    fontSize: 14,
                    color: AppColors.white,
                  ),
                ),
                onPressed: onNavigatePressed,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    AppStyle style, {
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
            HeroIcon(icon, size: 16, color: AppColors.sMapTeal),
            const SizedBox(width: 4),
            Text(
              value,
              style: style.blackTextColor.textTheme.boldStyle.copyWith(
                fontSize: 15,
                color: AppColors.grimReaper,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: style.blackTextColor.textTheme.textStyle.copyWith(
            fontSize: 11,
            color: AppColors.sonicSilver,
          ),
        ),
      ],
    );
  }
}
