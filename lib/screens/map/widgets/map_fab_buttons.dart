import 'package:s_map/commons/mixin/app_mixin.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:flutter/material.dart';

class MapFabButtons extends StatelessWidget with AppMixin {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onLocateMe;

  const MapFabButtons({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onLocateMe,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'map_zoom_in',
            onPressed: onZoomIn,
            backgroundColor: AppColors.white,
            foregroundColor: styles.blackTextColor,
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'map_zoom_out',
            onPressed: onZoomOut,
            backgroundColor: AppColors.white,
            foregroundColor: styles.blackTextColor,
            child: const Icon(Icons.remove),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'map_locate_me',
            onPressed: onLocateMe,
            backgroundColor: styles.colorScheme.primary,
            foregroundColor: styles.whiteTextColor,
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }
}
