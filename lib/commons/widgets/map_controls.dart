import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:s_map/commons/cubits/map_display_cubit/map_display_state.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class MapControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onLocateMe;
  final VoidCallback? onSwitchLayers;
  final VoidCallback? onToggleOrientation;
  final double rotation;
  final MapOrientationMode orientationMode;
  final Object? locateHeroTag;

  const MapControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onLocateMe,
    this.onSwitchLayers,
    this.onToggleOrientation,
    this.rotation = 0.0,
    this.orientationMode = MapOrientationMode.northUp,
    this.locateHeroTag,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Keep the compass in the control stack at all times. Hiding it based on
    // a tiny bearing threshold made the whole stack jump when the native map
    // reported 0°/360° around north.
    final bool showCompass = onToggleOrientation != null;

    return RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showCompass) ...[
            MapCompassButton(
              rotation: rotation,
              orientationMode: orientationMode,
              onTap: () {
                HapticFeedback.selectionClick();
                onToggleOrientation!();
              },
            ),
            const SizedBox(height: 10),
          ],
          _buildControlButton(
            context: context,
            icon: Icons.layers_rounded,
            tooltip: tr(LocaleKeys.map_switch_layers),
            onPressed: () {
              HapticFeedback.lightImpact();
              (onSwitchLayers ?? () {})();
            },
          ),
          const SizedBox(height: 10),
          // Compact Zoom Pill
          Container(
            width: 44,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: colorScheme.outline.withAlpha(50),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.add_rounded,
                      color: colorScheme.onSurface, size: 20),
                  tooltip: tr(LocaleKeys.map_zoom_in),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onZoomIn();
                  },
                  padding: EdgeInsets.zero,
                ),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: colorScheme.outline.withAlpha(80),
                ),
                IconButton(
                  icon: Icon(Icons.remove_rounded,
                      color: colorScheme.onSurface, size: 20),
                  tooltip: tr(LocaleKeys.map_zoom_out),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onZoomOut();
                  },
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          MapLocateButton(
            heroTag: locateHeroTag,
            onPressed: onLocateMe,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: colorScheme.outline.withAlpha(50),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: colorScheme.onSurface, size: 20),
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
