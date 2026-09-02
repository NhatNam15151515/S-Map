import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/commons/widgets/widgets.dart';

/// Floating controls bên phải khi đang dẫn đường.
///
/// Hiển thị:
/// - Nút la bàn (compass) để toggle heading-up ↔ north-up
/// - Nút recenter để khóa camera về vị trí hiện tại khi user đã kéo map
/// - Nút tròn tốc độ km/h
class NavigationMapControls extends StatelessWidget {
  final MapDisplayCubit displayCubit;
  final VoidCallback onRecenter;

  const NavigationMapControls({
    super.key,
    required this.displayCubit,
    required this.onRecenter,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return BlocBuilder<MapDisplayCubit, MapDisplayState>(
      buildWhen: (prev, curr) =>
          prev.rotation != curr.rotation ||
          prev.orientationMode != curr.orientationMode ||
          prev.isFollowingUser != curr.isFollowingUser,
      builder: (context, mapState) {
        final isFollowing = mapState.isFollowingUser;

        return BlocBuilder<NavigationBloc, NavigationState>(
          buildWhen: (prev, curr) =>
              prev.currentSpeedKmh != curr.currentSpeedKmh,
          builder: (context, navState) {
            final speedStr =
                RouteFormatHelper.formatSpeed(navState.currentSpeedKmh);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Compass button
                MapCompassButton(
                  rotation: mapState.rotation,
                  orientationMode: mapState.orientationMode,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    displayCubit.toggleOrientationMode();
                  },
                ),
                const SizedBox(height: 12),

                // 2. Recenter button (chỉ hiện khi user đã kéo map ra)
                if (!isFollowing) ...[
                  _buildCircleButton(
                    colorScheme: colorScheme,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      onRecenter();
                    },
                    child: Icon(
                      Icons.near_me_rounded,
                      color: colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 3. Speedometer circle
                _buildSpeedCircle(
                  colorScheme: colorScheme,
                  speedStr: speedStr,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCircleButton({
    required ColorScheme colorScheme,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _buildSpeedCircle({
    required ColorScheme colorScheme,
    required String speedStr,
  }) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.15),
          width: 0.8,
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            speedStr,
            style: colorScheme.onSurface.textTheme.boldStyle.copyWith(
              fontSize: 18,
              letterSpacing: -0.5,
              height: 1.0,
            ),
          ),
          Text(
            'km/h',
            style: colorScheme.onSurfaceVariant.textTheme.mediumStyle.copyWith(
              fontSize: 9,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
