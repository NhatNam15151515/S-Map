import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/routers/app_routes.dart';
import 'package:s_map/screens/main/home/widgets/home/home_interactive_map_layer.dart';

/// Coordinator quản lý logic chỉ đường và mở route drawing từ Home Screen.
///
/// Trách nhiệm:
/// - Bắt đầu chỉ đường tới POI đã chọn
/// - Mở màn hình vẽ route tùy chỉnh
/// - Chọn origin/destination cho route preview
class HomeRouteActions {
  final GlobalKey<HomeInteractiveMapLayerState> mapLayerKey;
  final MapDisplayCubit displayCubit;
  final RoutePreviewCubit routePreviewCubit;
  final VoidCallback onStateChanged;

  /// Callback để reset search state khi mở route drawing
  final VoidCallback onClearForRouteDrawing;

  HomeRouteActions({
    required this.mapLayerKey,
    required this.displayCubit,
    required this.routePreviewCubit,
    required this.onStateChanged,
    required this.onClearForRouteDrawing,
  });

  void handleDirections(PoiModel? selectedPoi) {
    if (selectedPoi == null) return;
    DLog.info(
        '🧭 [HomeScreen] "Chỉ đường" tapped for POI: "${selectedPoi.name}" (${selectedPoi.lat}, ${selectedPoi.lon})');
    mapLayerKey.currentState?.hideSearchResultMarkers();
    mapLayerKey.currentState?.clearSelectedPoiMarker(
      restoreSearchResults: false,
    );
    displayCubit.clearSelectedPoi();
    onStateChanged();
    routePreviewCubit.previewRouteToPoi(selectedPoi);
  }

  void handleOpenCustomRouteDrawing(
    BuildContext context, {
    PoiModel? poi,
    LatLng? destination,
    String? destinationName,
  }) {
    final mapState = displayCubit.state;
    final myPos = mapState.hasRealLocation ? mapState.currentPosition : null;
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

    context.push(AppRoutes.routeDrawing, extra: payload);
  }

  Future<void> handleSelectEndpointForRoute(
    BuildContext context, {
    required bool isOrigin,
    required bool mounted,
  }) async {
    final mapState = displayCubit.state;
    final searchCenter = mapState.currentPosition ?? mapState.center;
    final result = await context.push<dynamic>(
      AppRoutes.search,
      extra: searchCenter,
    );
    if (!mounted || result == null) return;

    final routeState = routePreviewCubit.state;
    if (isOrigin && routeState.destination == null) return;
    if (!isOrigin && routeState.origin == null) return;

    RoutePoint? point;
    String? name;

    if (result is SearchResultPayload && result.isLocation) {
      final pos = result.searchCenter ?? mapState.currentPosition;
      if (pos != null) {
        point = RoutePoint(lat: pos.latitude, lon: pos.longitude);
      }
    } else if (result is SearchResultPayload && result.isSingle) {
      final poi = result.selectedPoi!;
      point = RoutePoint(lat: poi.lat, lon: poi.lon);
      name = poi.name;
    } else if (result is PoiModel) {
      point = RoutePoint(lat: result.lat, lon: result.lon);
      name = result.name;
    }

    if (point == null) return;

    if (isOrigin) {
      routePreviewCubit.previewRouteBetweenPoints(
        origin: point,
        destination: routeState.destination!,
        originName: name,
        destinationName: routeState.destinationName,
        profile: routeState.profile,
      );
    } else {
      routePreviewCubit.previewRouteBetweenPoints(
        origin: routeState.origin!,
        destination: point,
        originName: routeState.originName,
        destinationName: name,
        profile: routeState.profile,
      );
    }
  }
}
