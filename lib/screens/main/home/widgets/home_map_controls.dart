import 'package:flutter/material.dart';
import 'package:s_map/commons/cubits/map_display_cubit/map_display_state.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/screens/map/widgets/map_compass_button.dart';

class HomeMapControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onLocateMe;
  final VoidCallback? onSwitchLayers;
  final VoidCallback? onToggleOrientation;
  final double rotation;
  final MapOrientationMode orientationMode;

  const HomeMapControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onLocateMe,
    this.onSwitchLayers,
    this.onToggleOrientation,
    this.rotation = 0.0,
    this.orientationMode = MapOrientationMode.northUp,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
        _buildControlButton(
          icon: Icons.layers_rounded,
          onPressed: onSwitchLayers ?? () {},
        ),
        const SizedBox(height: 10),
        _buildControlButton(
          icon: Icons.add_rounded,
          onPressed: onZoomIn,
        ),
        const SizedBox(height: 10),
        _buildControlButton(
          icon: Icons.remove_rounded,
          onPressed: onZoomOut,
        ),
        const SizedBox(height: 14),
        FloatingActionButton(
          heroTag: 'home_locate_me',
          onPressed: onLocateMe,
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.googleBlue,
          elevation: 3,
          shape: const CircleBorder(),
          child: const Icon(Icons.my_location_rounded, size: 24),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.1),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.googleDarkText, size: 20),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
