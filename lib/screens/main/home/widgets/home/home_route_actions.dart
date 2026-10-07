import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/routers/app_routes.dart';
import 'package:s_map/screens/main/home/widgets/drawing/save_custom_route_dialog.dart';
import 'package:s_map/screens/main/home/widgets/drawing/saved_routes_sheet.dart';
import 'package:s_map/screens/main/home/widgets/map/home_interactive_map_layer.dart';
import 'package:s_map/screens/main/home/widgets/home/home_search_results_coordinator.dart';

/// Các thao tác chỉ đường, tìm điểm đến và điều khiển tuyến từ Home.
class HomeRouteActions {
  final GlobalKey<HomeInteractiveMapLayerState> mapLayerKey;
  final MapDisplayCubit displayCubit;
  final RoutePreviewCubit routePreviewCubit;
  final VoidCallback onStateChanged;

  final VoidCallback onClearForRouteDrawing;

  final void Function(List<PoiModel> pois, String? query) onSearchResults;

  final ValueChanged<RouteDrawingPayload>? onOpenRouteDrawing;
  final ValueChanged<PoiModel>? onAppendDestination;
  final ValueChanged<LatLng>? onAppendLocation;

  HomeRouteActions({
    required this.mapLayerKey,
    required this.displayCubit,
    required this.routePreviewCubit,
    required this.onStateChanged,
    required this.onClearForRouteDrawing,
    required this.onSearchResults,
    this.onOpenRouteDrawing,
    this.onAppendDestination,
    this.onAppendLocation,
  });

  void handleDirections(PoiModel? selectedPoi) {
    if (selectedPoi == null) return;
    DLog.info(
      '🧭 [HomeScreen] "Chỉ đường" tapped for POI: "${selectedPoi.name}" (${selectedPoi.lat}, ${selectedPoi.lon})',
    );
    mapLayerKey.currentState?.hideSearchResultMarkers();
    mapLayerKey.currentState?.clearSelectedPoiMarker(
      restoreSearchResults: false,
    );
    displayCubit.clearSelectedPoi();
    onStateChanged();
    handleOpenCustomRouteDrawing(null, poi: selectedPoi);
  }

  void handleOpenCustomRouteDrawing(
    BuildContext? context, {
    PoiModel? poi,
    LatLng? destination,
    String? destinationName,
  }) {
    final mapState = displayCubit.state;
    final myPos = mapState.hasRealLocation
        ? mapState.currentPosition
        : mapState.center;
    final destLatLng =
        destination ?? (poi != null ? LatLng(poi.lat, poi.lon) : null);
    final name = destinationName ?? poi?.name;

    final payload = RouteDrawingPayload(
      initialOrigin: myPos,
      initialDestination: destLatLng,
      destinationName: name,
      destinationPoi: poi,
    );

    mapLayerKey.currentState?.clearAll();
    displayCubit.clearSelectedPoi();
    final hasActiveRoutePreview =
        routePreviewCubit.state.isLoading || routePreviewCubit.state.isSuccess;
    if (hasActiveRoutePreview) {
      routePreviewCubit.clearRoute();
    }
    onClearForRouteDrawing();

    final openRouteDrawing = onOpenRouteDrawing;
    if (openRouteDrawing != null) {
      openRouteDrawing(payload);
      return;
    }

    if (context != null) {
      context.go(AppRoutes.home, extra: payload);
    }
  }

  /// Nạp điểm đến mới vào lộ trình và mở chế độ vẽ route.
  void handleAddDestination(BuildContext context, PoiModel poi) {
    if (onAppendDestination != null) {
      onAppendDestination!(poi);
      return;
    }
    final routeState = routePreviewCubit.state;
    final mapState = displayCubit.state;

    final originPos = routeState.origin != null
        ? LatLng(routeState.origin!.lat, routeState.origin!.lon)
        : (mapState.hasRealLocation
              ? mapState.currentPosition
              : mapState.center);

    final destPos = routeState.destination != null
        ? LatLng(routeState.destination!.lat, routeState.destination!.lon)
        : null;

    final newPoint = LatLng(poi.lat, poi.lon);

    final payload = RouteDrawingPayload(
      initialOrigin: originPos,
      initialDestination: destPos,
      destinationName: routeState.destinationName,
      additionalWaypoints: [newPoint],
    );

    mapLayerKey.currentState?.clearAll();
    displayCubit.clearSelectedPoi();
    routePreviewCubit.clearRoute();
    onClearForRouteDrawing();

    final openRouteDrawing = onOpenRouteDrawing;
    if (openRouteDrawing != null) {
      openRouteDrawing(payload);
      return;
    }

    context.go(AppRoutes.home, extra: payload);
  }

  void handleCurrentLocation(BuildContext context, LatLng location) {
    if (routePreviewCubit.state.destination != null &&
        onAppendLocation != null) {
      onAppendLocation!(location);
      return;
    }
    displayCubit.focusCurrentLocation(location);
  }

  /// Mở màn hình tìm kiếm để thêm điểm đến vào lộ trình hiện tại
  Future<void> handleOpenAddDestinationSearch(
    BuildContext context, {
    ValueChanged<PoiModel>? onSelectedPoi,
    ValueChanged<LatLng>? onSelectedLocation,
  }) async {
    final mapState = displayCubit.state;
    final searchCenter = mapState.currentPosition ?? mapState.center;
    var result = await context.push<dynamic>(
      AppRoutes.search,
      extra: SearchScreenArgs(
        userLocation: searchCenter,
        hasExistingDestinations: true,
      ),
    );
    if (!context.mounted || result == null) return;

    if (result is SearchResultPayload && result.isAll) {
      onSearchResults(result.allResults ?? const [], result.submittedQuery);
      return;
    }

    final resolvedResult = await HomeSearchResultsCoordinator.resolvePayload(
      context,
      result,
      hasExistingDestinations: true,
    );
    if (!context.mounted || resolvedResult == null) return;

    if ((resolvedResult.isAddDestination || resolvedResult.isSingle) &&
        resolvedResult.selectedPoi != null) {
      final poi = resolvedResult.selectedPoi!;
      if (onSelectedPoi != null) {
        onSelectedPoi(poi);
      } else {
        handleAddDestination(context, poi);
      }
    } else if (resolvedResult.isLocation &&
        resolvedResult.searchCenter != null) {
      final location = resolvedResult.searchCenter!;
      if (onSelectedLocation != null) {
        onSelectedLocation(location);
      } else if (onAppendLocation != null) {
        onAppendLocation!(location);
      } else {
        displayCubit.focusCurrentLocation(location);
      }
    }
  }

  static void showSaveRouteDialog({
    required BuildContext context,
    required RouteDrawingBloc drawingBloc,
  }) {
    final defaultName = tr(
      LocaleKeys.route_drawing_ui_default_route_name,
      args: [DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())],
    );
    SaveCustomRouteDialog.show(
      context,
      initialName: defaultName,
      onSave: (name, description) {
        drawingBloc.add(
          RouteDrawingSaveRoute(name: name, description: description),
        );
      },
    );
  }

  static void showSavedRoutesSheet({
    required BuildContext context,
    required RouteDrawingBloc drawingBloc,
    required SavedRoutesCubit savedRoutesCubit,
  }) {
    SavedRoutesSheet.show(
      context,
      onRouteSelected: (route) => drawingBloc.add(RouteDrawingLoadRoute(route)),
      onRouteDeleted: savedRoutesCubit.deleteRoute,
    );
  }

  static void startNavigationFromDrawnRoute({
    required BuildContext context,
    required RouteDrawingState state,
  }) {
    if (!state.hasRoute) return;
    final rawPoints = state.fullPolyline
        .map((point) => [point.lat, point.lon])
        .toList();
    final customName = tr(LocaleKeys.route_drawing_ui_custom_route_name);
    final destinationName =
        state.points.isNotEmpty && state.points.last.streetName.isNotEmpty
        ? state.points.last.streetName
        : customName;
    final instructions = state.segments
        .expand((segment) => segment.instructions)
        .toList();
    if (instructions.isEmpty) {
      instructions.add(
        RouteInstruction(
          text: tr(LocaleKeys.route_drawing_ui_follow_custom_route),
          streetName: customName,
          distance: state.totalDistance,
          time: state.totalTime,
          sign: 0,
          points: rawPoints,
        ),
      );
    }
    final customRoute = RouteResult(
      isSuccess: true,
      distance: state.totalDistance,
      time: state.totalTime,
      points: rawPoints,
      instructions: instructions,
    );
    final originWaypoint = state.points.first;
    final originName = originWaypoint.displayName.trim().isNotEmpty
        ? originWaypoint.displayName.trim()
        : originWaypoint.streetName.trim();
    try {
      context.read<NavigationBloc>().add(
        StartNavigation(
          initialRoute: customRoute,
          origin: RoutePoint(
            lat: originWaypoint.originalLat,
            lon: originWaypoint.originalLon,
          ),
          originName: originName.isEmpty ? null : originName,
          destination: state.fullPolyline.last,
          destinationName: destinationName,
        ),
      );
    } catch (_) {}
    context.go(AppRoutes.home);
  }
}
