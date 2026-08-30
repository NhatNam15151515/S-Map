import 'package:flutter/material.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/widgets/widgets.dart';

class MapFabButtons extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onLocateMe;
  final VoidCallback? onToggleOrientation;
  final double rotation;
  final MapOrientationMode orientationMode;

  const MapFabButtons({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onLocateMe,
    this.onToggleOrientation,
    this.rotation = 0.0,
    this.orientationMode = MapOrientationMode.northUp,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Positioned(
      right: 16,
      bottom: 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onToggleOrientation != null) ...[
            MapCompassButton(
              rotation: rotation,
              orientationMode: orientationMode,
              onTap: onToggleOrientation!,
            ),
            const SizedBox(height: 10),
          ],
          FloatingActionButton.small(
            heroTag: 'map_zoom_in',
            onPressed: onZoomIn,
            backgroundColor: colorScheme.surface,
            foregroundColor: colorScheme.onSurface,
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'map_zoom_out',
            onPressed: onZoomOut,
            backgroundColor: colorScheme.surface,
            foregroundColor: colorScheme.onSurface,
            child: const Icon(Icons.remove),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'map_locate_me',
            onPressed: onLocateMe,
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }
}
