import 'dart:math';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/screens/main/home/widgets/map/widgets.dart';

/// Canvas hiển thị MapView và các trạng thái overlay (Loading, Error) của bản đồ
class HomeMapCanvas extends StatelessWidget {
  final MapDisplayState state;
  final NavigationState navState;
  final MapDisplayCubit displayCubit;
  final void Function(MapLibreMapController) onMapCreated;
  final VoidCallback onStyleLoaded;
  final VoidCallback onCameraIdle;
  final void Function(Point<double>, LatLng) onMapClick;
  final void Function(Point<double>, LatLng) onMapLongClick;

  const HomeMapCanvas({
    super.key,
    required this.state,
    required this.navState,
    required this.displayCubit,
    required this.onMapCreated,
    required this.onStyleLoaded,
    required this.onCameraIdle,
    required this.onMapClick,
    required this.onMapLongClick,
  });

  @override
  Widget build(BuildContext context) {
    final isNavigating = navState.isNavigating;

    return Stack(
      children: [
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerMove: (event) {
            if (isNavigating && displayCubit.state.isFollowingUser) {
              if (event.delta.distanceSquared > 4) {
                displayCubit.unfollowUser();
              }
            }
          },
          child: MapView(
            key: const Key('map_view_main'),
            styleString: state.styleString,
            nativeCompassEnabled: false,
            myLocationTrackingMode: isNavigating
                ? MyLocationTrackingMode.none
                : MyLocationTrackingMode.tracking,
            myLocationRenderMode: isNavigating
                ? MyLocationRenderMode.compass
                : MyLocationRenderMode.normal,
            onMapCreated: onMapCreated,
            onStyleLoadedCallback: onStyleLoaded,
            onCameraTrackingDismissed: displayCubit.onCameraTrackingDismissed,
            onCameraMove: displayCubit.onCameraMove,
            onCameraIdle: onCameraIdle,
            onMapClick: onMapClick,
            onMapLongClick: onMapLongClick,
          ),
        ),
        if (state.status == MapDisplayStatus.loading)
          const Positioned.fill(
            child: Center(child: CircularProgressIndicator()),
          ),
        if (state.status == MapDisplayStatus.error)
          MapErrorOverlay(
            errorMessage: state.errorMessageKey != null
                ? tr(state.errorMessageKey!)
                : tr(LocaleKeys.map_error_load),
            onRetry: displayCubit.locateMe,
          ),
      ],
    );
  }
}
