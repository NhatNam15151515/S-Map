import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'route_drawing_point_entry_prompt.dart';
import 'route_drawing_stats_row.dart';

class RouteDrawingBottomCard extends StatelessWidget {
  final int pointCount;
  final double distanceMeters;
  final int durationMs;
  final bool isLoading;
  final bool isStraightLineMode;
  final bool isDrawingMode;
  final Widget? extraContent;
  final VoidCallback onSavePressed;
  final VoidCallback onNavigatePressed;
  final VoidCallback? onToggleDrawingMode;
  final VoidCallback? onClose;

  const RouteDrawingBottomCard({
    super.key,
    required this.pointCount,
    required this.distanceMeters,
    required this.durationMs,
    required this.isLoading,
    this.isStraightLineMode = false,
    this.isDrawingMode = true,
    this.extraContent,
    required this.onSavePressed,
    required this.onNavigatePressed,
    this.onToggleDrawingMode,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomPadding + 16,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        onPanStart: (_) {},
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
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: colorScheme.primary.withValues(alpha: 0.2),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(colorScheme.primary),
                  ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: _buildContent(context, colorScheme),
                ),
              ],
            ),
            // Nút Close ở góc phải của Bottom Sheet
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  key: const Key('route_drawing_bottom_sheet_close_button'),
                  customBorder: const CircleBorder(),
                  onTap: onClose ?? () => Navigator.of(context).maybePop(),
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildContent(BuildContext context, ColorScheme colorScheme) {
    if (pointCount < 2) {
      return RouteDrawingPointEntryPrompt(pointCount: pointCount);
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
        if (extraContent != null) ...[
          const SizedBox(height: 12),
          extraContent!,
        ],
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
      spacing: 12, // khoảng cách đều, không set cứng size nút
      children: [
        if (onToggleDrawingMode != null)
          Expanded(
            flex: 1,
            child: IconButton.filledTonal(
              tooltip: isDrawingMode
                  ? tr(LocaleKeys.directions)
                  : tr(LocaleKeys.route_drawing),
              style: IconButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: Icon(
                isDrawingMode
                    ? Icons.directions_outlined
                    : Icons.gesture_rounded,
                color: colorScheme.primary,
                size: 20,
              ),
              onPressed: onToggleDrawingMode,
            ),
          ),
        Expanded(
          flex: 2, // nút Save to hơn
          child: OutlinedButton(
            key: const Key('route_drawing_save_button'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              side: BorderSide(color: colorScheme.primary, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: onSavePressed,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tr(LocaleKeys.route_drawing_ui_save_route),
                maxLines: 1,
                style: colorScheme.primary.textTheme.semiBoldStyle.copyWith(
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 2, // nút Navigate to hơn
          child: ElevatedButton(
            key: const Key('route_drawing_navigate_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: onNavigatePressed,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tr(LocaleKeys.route_drawing_ui_start_navigation),
                maxLines: 1,
                style: colorScheme.onPrimary.textTheme.semiBoldStyle.copyWith(
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
