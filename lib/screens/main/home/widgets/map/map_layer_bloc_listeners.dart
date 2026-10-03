import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';

/// Widget chuyên biệt xử lý tất cả BlocListener cho HomeInteractiveMapLayer.
///
/// Trách nhiệm:
/// - Lắng nghe MapDisplayCubit (style, camera, selectedPoi, error)
/// - Lắng nghe ViewportSearchBloc (render POI list)
/// - Lắng nghe RoutePreviewCubit (draw/clear route)
/// - Lắng nghe NavigationBloc (navigation camera + route progress)
/// - Lắng nghe FavoritesCubit (refresh memory markers)
class MapLayerBlocListeners extends StatelessWidget {
  final Widget child;
  final void Function(BuildContext, MapDisplayState) onMapDisplayChanged;
  final void Function(BuildContext, ViewportSearchState) onViewportSearchChanged;
  final void Function(RoutePreviewState) onRoutePreviewChanged;
  final void Function(NavigationState) onNavigationChanged;
  final VoidCallback onFavoritesChanged;

  const MapLayerBlocListeners({
    super.key,
    required this.child,
    required this.onMapDisplayChanged,
    required this.onViewportSearchChanged,
    required this.onRoutePreviewChanged,
    required this.onNavigationChanged,
    required this.onFavoritesChanged,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<FavoritesCubit, FavoritesState>(
          listenWhen: (prev, curr) => prev.favorites != curr.favorites,
          listener: (context, state) => onFavoritesChanged(),
        ),
        BlocListener<MapDisplayCubit, MapDisplayState>(
          listenWhen: (prev, curr) =>
              prev.cameraAction != curr.cameraAction ||
              prev.selectedPoi != curr.selectedPoi ||
              prev.status != curr.status ||
              prev.styleString != curr.styleString,
          listener: onMapDisplayChanged,
        ),
        BlocListener<ViewportSearchBloc, ViewportSearchState>(
          listenWhen: (prev, curr) =>
              prev.pois != curr.pois || prev.status != curr.status,
          listener: onViewportSearchChanged,
        ),
        BlocListener<RoutePreviewCubit, RoutePreviewState>(
          listenWhen: (prev, curr) =>
              prev.status != curr.status ||
              prev.routeResult != curr.routeResult,
          listener: (context, state) => onRoutePreviewChanged(state),
        ),
        BlocListener<NavigationBloc, NavigationState>(
          listenWhen: (prev, curr) =>
              prev.status != curr.status ||
              prev.currentLat != curr.currentLat ||
              prev.currentLon != curr.currentLon ||
              prev.currentHeading != curr.currentHeading ||
              prev.currentSpeedKmh != curr.currentSpeedKmh ||
              prev.currentSegmentIndex != curr.currentSegmentIndex ||
              prev.currentRoute != curr.currentRoute,
          listener: (context, state) => onNavigationChanged(state),
        ),
      ],
      child: child,
    );
  }
}
