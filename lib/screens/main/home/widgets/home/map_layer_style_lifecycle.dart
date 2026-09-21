import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/models/models.dart';

/// Mixin quản lý lifecycle của map style và route/navigation rendering.
///
/// Trách nhiệm:
/// - Khởi tạo assets khi style loaded
/// - Restore trạng thái map sau khi đổi style
/// - Apply style mới khi theme thay đổi
mixin MapLayerStyleLifecycle<T extends StatefulWidget> on State<T>, AppMixin {
  MapLibreMapController? get mapController;
  MapSymbolManager get symbolManager;
  MapRouteManager get routeManager;
  MapDisplayCubit get displayCubit;
  ViewportSearchBloc get viewportBloc;
  RoutePreviewCubit get routePreviewCubit;

  String? lastAppliedMapStyle;

  /// Cờ theo dõi route đã render trong navigation (tránh re-draw không cần thiết)
  RouteResult? renderedNavRoute;

  Future<void> applyMapStyle(String styleString) async {
    if (styleString.isEmpty || styleString == lastAppliedMapStyle) return;

    final controller = mapController;
    if (controller == null) return;

    lastAppliedMapStyle = styleString;
    try {
      await controller.setStyle(styleString);
    } catch (error, stack) {
      lastAppliedMapStyle = null;
      DLog.warning('⚠️ [Map] Không thể áp dụng style bản đồ: $error', stack);
    }
  }

  Future<void> onStyleLoaded() async {
    final navigationBloc = context.read<NavigationBloc>();
    symbolManager.resetAssetLoaded();
    routeManager.resetAssetLoaded();
    await symbolManager.loadMarkerAssets(mapController, force: true);
    await symbolManager.initLayers(mapController);
    await routeManager.loadMarkerAssets(mapController, force: true);
    if (!mounted) return;

    await refreshMemoryMarkers();

    final viewportState = viewportBloc.state;
    final previewState = routePreviewCubit.state;
    final currentNavigationState = navigationBloc.state;
    final routeOrNavigationActive = previewState.isLoading ||
        previewState.isSuccess ||
        currentNavigationState.isNavigating;
    if (!routeOrNavigationActive &&
        viewportState.status == ViewportSearchStatus.success &&
        viewportState.selectedCategory != CategoryConstants.all &&
        viewportState.pois.isNotEmpty) {
      await symbolManager.renderPoiList(mapController, viewportState.pois);
    }
    if (!routeOrNavigationActive && displayCubit.state.selectedPoi != null) {
      await setSelectedPoiMarker(displayCubit.state.selectedPoi!);
    }

    lastAppliedMapStyle = displayCubit.state.styleString;
    await displayCubit.onStyleLoaded();

    if (previewState.isSuccess &&
        previewState.routeResult != null &&
        previewState.origin != null &&
        previewState.destination != null) {
      routeManager.drawRoute(
        controller: mapController,
        routeResult: previewState.routeResult!,
        origin: previewState.origin!,
        destination: previewState.destination!,
        destinationName: previewState.destinationName,
      );
    }

    if (!mounted) return;
    final navState = navigationBloc.state;
    if (navState.isNavigating &&
        navState.currentRoute != null &&
        navState.origin != null &&
        navState.destination != null) {
      routeManager.drawRoute(
        controller: mapController,
        routeResult: navState.currentRoute!,
        origin: navState.origin!,
        destination: navState.destination!,
        destinationName: navState.destinationName,
      );
      renderedNavRoute = navState.currentRoute;
    }
  }

  /// Cần implement trong class chính
  Future<void> refreshMemoryMarkers();

  /// Cần implement trong class chính
  Future<void> setSelectedPoiMarker(PoiModel poi);
}
