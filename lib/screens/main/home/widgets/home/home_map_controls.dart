import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/widgets/widgets.dart';

class HomeMapControls extends StatelessWidget {
  final MapDisplayCubit displayCubit;

  const HomeMapControls({
    super.key,
    required this.displayCubit,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 220,
      child: BlocBuilder<MapDisplayCubit, MapDisplayState>(
        buildWhen: (previous, current) =>
            previous.rotation != current.rotation ||
            previous.orientationMode != current.orientationMode,
        builder: (context, state) {
          return MapControls(
            onZoomIn: displayCubit.zoomIn,
            onZoomOut: displayCubit.zoomOut,
            onLocateMe: displayCubit.locateMe,
            onToggleOrientation: displayCubit.toggleOrientationMode,
            rotation: state.rotation,
            orientationMode: state.orientationMode,
            locateHeroTag: 'home_screen_locate_fab',
          );
        },
      ),
    );
  }
}
