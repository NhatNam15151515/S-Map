import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:s_map/commons/styles/styles.dart';
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
    final colorScheme = context.colorScheme;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomPadding + 16,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.15),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.12),
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
              LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: _buildContent(context, colorScheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ColorScheme colorScheme) {
    if (pointCount == 0) {
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

    if (pointCount == 1) {
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
                colorScheme,
                icon: HeroIcons.mapPin,
                value: '${distanceKm.toStringAsFixed(1)} km',
                label: tr(LocaleKeys.routing_trip_distance),
              ),
            ),
            Container(
              width: 1,
              height: 32,
              color: colorScheme.outline.withValues(alpha: 0.2),
            ),
            Expanded(
              child: _buildStatItem(
                context,
                colorScheme,
                icon: HeroIcons.clock,
                value: '$durationMinutes ${tr(LocaleKeys.routing_unit_minute)}',
                label: tr(LocaleKeys.routing_trip_duration),
              ),
            ),
            Container(
              width: 1,
              height: 32,
              color: colorScheme.outline.withValues(alpha: 0.2),
            ),
            Expanded(
              child: _buildStatItem(
                context,
                colorScheme,
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
                  side: BorderSide(color: colorScheme.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: HeroIcon(
                  HeroIcons.bookmark,
                  size: 18,
                  color: colorScheme.primary,
                ),
                label: Text(
                  tr(LocaleKeys.route_drawing_ui_save_route),
                  style: colorScheme.primary.textTheme.semiBoldStyle.copyWith(
                    fontSize: 14,
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
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: Icon(
                  Icons.navigation_rounded,
                  size: 18,
                  color: colorScheme.onPrimary,
                ),
                label: Text(
                  tr(LocaleKeys.route_drawing_ui_start_navigation),
                  style: colorScheme.onPrimary.textTheme.boldStyle.copyWith(
                    fontSize: 14,
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
