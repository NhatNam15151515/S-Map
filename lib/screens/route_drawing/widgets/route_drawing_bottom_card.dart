import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/screens/route_drawing/widgets/route_drawing_empty_prompt.dart';
import 'package:s_map/screens/route_drawing/widgets/route_drawing_stats_row.dart';

class RouteDrawingBottomCard extends StatelessWidget {
  final int pointCount;
  final double distanceMeters;
  final int durationMs;
  final bool isLoading;
  final bool isStraightLineMode;
  final VoidCallback onSavePressed;
  final VoidCallback onNavigatePressed;

  const RouteDrawingBottomCard({
    super.key,
    required this.pointCount,
    required this.distanceMeters,
    required this.durationMs,
    required this.isLoading,
    this.isStraightLineMode = false,
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
    if (pointCount < 2) {
      return RouteDrawingEmptyPrompt(pointCount: pointCount);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isStraightLineMode) _buildStraightLineBadge(colorScheme),
        RouteDrawingStatsRow(
          distanceMeters: distanceMeters,
          durationMs: durationMs,
          pointCount: pointCount,
        ),
        const SizedBox(height: 16),
        _buildActionButtons(colorScheme),
      ],
    );
  }

  Widget _buildStraightLineBadge(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.airplanemode_active_rounded,
            size: 14,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            tr(LocaleKeys.route_drawing_ui_straight_line_mode_active_badge),
            style: colorScheme.primary.textTheme.semiBoldStyle.copyWith(
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ColorScheme colorScheme) {
    return Row(
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
    );
  }
}
