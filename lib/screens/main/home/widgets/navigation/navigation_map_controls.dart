import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'navigation_speedometer.dart';

/// Floating controls bên phải khi đang dẫn đường.
///
/// Quản lý layout vị trí của:
/// - Nút la bàn (compass) để toggle heading-up ↔ north-up
/// - Nút recenter để khóa camera về vị trí hiện tại khi user đã kéo map
/// - [NavigationSpeedometer] hiển thị tốc độ km/h
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Compass button (lắng nghe rotation & orientationMode)
        BlocBuilder<MapDisplayCubit, MapDisplayState>(
          buildWhen: (prev, curr) =>
              prev.rotation != curr.rotation ||
              prev.orientationMode != curr.orientationMode,
          builder: (context, mapState) {
            return MapCompassButton(
              rotation: mapState.rotation,
              orientationMode: mapState.orientationMode,
              onTap: () {
                HapticFeedback.selectionClick();
                displayCubit.toggleOrientationMode();
              },
            );
          },
        ),
        const SizedBox(height: 12),

        // 2. Recenter button (chỉ lắng nghe trạng thái isFollowingUser)
        BlocBuilder<MapDisplayCubit, MapDisplayState>(
          buildWhen: (prev, curr) =>
              prev.isFollowingUser != curr.isFollowingUser,
          builder: (context, mapState) {
            if (mapState.isFollowingUser) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: MapCircleIconButton(
                size: 48,
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
            );
          },
        ),

        // 3. Speedometer circle (độc lập, tự lắng nghe NavigationBloc)
        const NavigationSpeedometer(),
      ],
    );
  }
}
