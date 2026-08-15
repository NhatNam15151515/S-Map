import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    return RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onToggleOrientation != null) ...[
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
            icon: Icons.layers_rounded,
            tooltip: 'Chuyển đổi lớp bản đồ',
            onPressed: () {
              HapticFeedback.lightImpact();
              (onSwitchLayers ?? () {})();
            },
          ),
          const SizedBox(height: 10),
          _buildControlButton(
            icon: Icons.add_rounded,
            tooltip: 'Phóng to',
            onPressed: () {
              HapticFeedback.lightImpact();
              onZoomIn();
            },
          ),
          const SizedBox(height: 8),
          _buildControlButton(
            icon: Icons.remove_rounded,
            tooltip: 'Thu nhỏ',
            onPressed: () {
              HapticFeedback.lightImpact();
              onZoomOut();
            },
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'home_locate_me_${DateTime.now().microsecondsSinceEpoch}',
            tooltip: 'Vị trí hiện tại',
            onPressed: () {
              HapticFeedback.mediumImpact();
              onLocateMe();
            },
            backgroundColor: AppColors.white,
            foregroundColor: AppColors.googleBlue,
            elevation: 4,
            shape: const CircleBorder(),
            child: const Icon(Icons.my_location_rounded, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
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
            color: Color.fromRGBO(0, 0, 0, 0.08),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.googleDarkText, size: 20),
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
