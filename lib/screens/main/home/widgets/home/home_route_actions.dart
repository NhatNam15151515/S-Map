import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/commons/widgets/widgets.dart';
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

  /// Hiển thị kết quả tìm kiếm inline trên Home khi đang preview route.
  final void Function(List<PoiModel> pois, String? query) onSearchResults;

  HomeRouteActions({
    required this.mapLayerKey,
    required this.displayCubit,
    required this.routePreviewCubit,
    required this.onStateChanged,
    required this.onClearForRouteDrawing,
    required this.onSearchResults,
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

  /// Nạp điểm đến mới vào lộ trình và chuyển sang màn hình vẽ đường
  void handleAddDestination(BuildContext context, PoiModel poi) {
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

    context.push(AppRoutes.routeDrawing, extra: payload);
  }

  /// Mở màn hình tìm kiếm để thêm điểm đến vào lộ trình hiện tại
  Future<void> handleOpenAddDestinationSearch(BuildContext context) async {
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

    final resolvedResult = await resolveSearchResultPayload(
      context,
      result,
      hasExistingDestinations: true,
    );
    if (!context.mounted || resolvedResult == null) return;

    if ((resolvedResult.isAddDestination || resolvedResult.isSingle) &&
        resolvedResult.selectedPoi != null) {
      handleAddDestination(context, resolvedResult.selectedPoi!);
    }
  }

  Future<void> handleSelectEndpointForRoute(
    BuildContext context, {
    required bool isOrigin,
    required bool mounted,
  }) async {
    final mapState = displayCubit.state;
    final searchCenter = mapState.currentPosition ?? mapState.center;
    var result = await context.push<dynamic>(
      AppRoutes.search,
      extra: SearchScreenArgs(
        userLocation: searchCenter,
        hasExistingDestinations: routePreviewCubit.state.destination != null,
      ),
    );
    if (!context.mounted || !mounted || result == null) return;

    final resolvedResult = await resolveSearchResultPayload(
      context,
      result,
      hasExistingDestinations: routePreviewCubit.state.destination != null,
    );
    if (!context.mounted || !mounted || resolvedResult == null) return;

    if (resolvedResult.isAddDestination && resolvedResult.selectedPoi != null) {
      handleAddDestination(context, resolvedResult.selectedPoi!);
      return;
    }

    final routeState = routePreviewCubit.state;
    if (isOrigin && routeState.destination == null) return;
    if (!isOrigin && routeState.origin == null) return;

    RoutePoint? point;
    String? name;

    if (resolvedResult.isLocation) {
      final pos = resolvedResult.searchCenter ?? mapState.currentPosition;
      if (pos != null) {
        point = RoutePoint(lat: pos.latitude, lon: pos.longitude);
      }
    } else if (resolvedResult.isSingle) {
      final poi = resolvedResult.selectedPoi!;
      point = RoutePoint(lat: poi.lat, lon: poi.lon);
      name = poi.name;
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
