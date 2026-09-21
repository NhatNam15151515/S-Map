import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/generated/locale_keys.g.dart';

/// Overlay tâm ngắm (crosshair reticle) và nút thêm điểm nổi ở giữa
class RouteDrawingCrosshairOverlay extends StatelessWidget {
  final bool isLoading;
  final bool hasPoints;
  final VoidCallback onAddPoint;
  final double bottomOffset;

  const RouteDrawingCrosshairOverlay({
    super.key,
    required this.isLoading,
    required this.hasPoints,
    required this.onAddPoint,
    required this.bottomOffset,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        // Tâm ngắm ở giữa màn hình
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            if (!isLoading) {
              onAddPoint();
            }
          },
          child: Center(
            child: SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.85),
                        width: 2.0,
                      ),
                      color: colorScheme.primary.withValues(alpha: 0.12),
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.primary,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  // Reticle cross lines
                  Positioned(
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 1.5,
                      color: colorScheme.primary.withValues(alpha: 0.6),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 1.5,
                      color: colorScheme.primary.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Nút thêm điểm nổi
        Positioned(
          left: 0,
          right: 0,
          bottom: bottomOffset,
          child: Center(
            child: ElevatedButton.icon(
              key: const Key('route_drawing_add_point_center_btn'),
              onPressed: isLoading ? null : onAddPoint,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                elevation: 6,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                shadowColor: colorScheme.primary.withValues(alpha: 0.4),
              ),
              icon: const Icon(Icons.add_location_alt_rounded, size: 20),
              label: Text(
                !hasPoints
                    ? tr(LocaleKeys.route_drawing_ui_center_add_start_point)
                    : tr(LocaleKeys.route_drawing_ui_center_add_next_point),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
