import 'dart:math';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/main/home/widgets/widgets.dart';

class HomeInteractiveMapLayer extends StatefulWidget {
  final ValueChanged<PoiModel> onPoiTapped;
  final ValueChanged<bool> onSearchAreaVisibilityChanged;

  const HomeInteractiveMapLayer({
    super.key,
    required this.onPoiTapped,
    required this.onSearchAreaVisibilityChanged,
  });

  @override
  State<HomeInteractiveMapLayer> createState() =>
      HomeInteractiveMapLayerState();
}

class HomeInteractiveMapLayerState extends State<HomeInteractiveMapLayer>
    with AppMixin {
  MapLibreMapController? _mapController;
  final MapSymbolManager _symbolManager = MapSymbolManager();
  final MapCameraController _cameraController = MapCameraController();
  final MapRouteManager _routeManager = MapRouteManager();
  RouteResult? _renderedNavRoute;

  MapDisplayCubit get displayCubit => context.read<MapDisplayCubit>();
  ViewportSearchBloc get viewportBloc => context.read<ViewportSearchBloc>();
  RoutePreviewCubit get routePreviewCubit => context.read<RoutePreviewCubit>();

  /// Kích hoạt tìm kiếm theo danh mục trong khung nhìn hiện tại (đồng bộ từ UI)
  void searchByCategory(String category) {
    _cameraController.executeInVisibleRegion(_mapController, (bounds) {
      if (mounted) {
        viewportBloc.add(
          ViewportCategoryFilterChanged(category, bounds: bounds),
        );
      }
    });
  }

  /// Kích hoạt tìm kiếm tại khu vực hiện tại kết hợp query (đồng bộ từ UI)
  void searchThisArea({String? query}) {
    _cameraController.executeInVisibleRegion(_mapController, (bounds) {
      if (mounted) {
        viewportBloc.add(
          SearchThisAreaPressed(bounds, query: query),
        );
      }
    });
  }

  void handleCameraAction(MapCameraAction action) {
    _cameraController.applyCameraAction(_mapController, action);
  }

  void _onCameraIdle() {
    _cameraController.handleCameraIdle(
      controller: _mapController,
      onInitialSearch: (bounds) {
        if (mounted) {
          viewportBloc.add(SearchInViewportRequested(bounds));
        }
      },
      onSearchAreaVisibilityChanged: (visible) {
        if (mounted) {
          widget.onSearchAreaVisibilityChanged(visible);
        }
      },
    );
  }

  /// Hiển thị ghim đỏ cho một địa điểm cụ thể được chọn
  void setSelectedPoiMarker(PoiModel poi) {
    _symbolManager.setSelectedPoiMarker(_mapController, poi);
  }

  /// Xóa ghim đơn lẻ khi đóng thẻ POI
  void clearSelectedPoiMarker() {
    _symbolManager.clearSelectedPoiMarker(_mapController);
  }

  /// Hiển thị danh sách kết quả tìm kiếm và fit camera bao quanh
  void showSearchResults(List<PoiModel> pois) {
    _symbolManager.showSearchResults(_mapController, pois);
  }

  /// Chuyển tiếp sự kiện chạm giữ (Long Press) trên bản đồ trực tiếp sang Cubit
  void _onMapLongClick(Point<double> point, LatLng latLng) {
    DLog.info('👆 [Map] Long press detected at: (${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)})');
    routePreviewCubit.previewRouteToCoordinate(latLng);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<MapDisplayCubit, MapDisplayState>(
          listenWhen: (prev, curr) =>
              prev.cameraAction != curr.cameraAction ||
              prev.selectedPoi != curr.selectedPoi ||
              prev.status != curr.status,
          listener: (context, state) {
            if (state.cameraAction != null) {
              handleCameraAction(state.cameraAction!);
            }
            if (state.selectedPoi != null) {
              setSelectedPoiMarker(state.selectedPoi!);
            }
            if (state.status == MapDisplayStatus.error &&
                state.errorMessageKey != null) {
              showError(tr(state.errorMessageKey!));
            }
          },
        ),
        BlocListener<ViewportSearchBloc, ViewportSearchState>(
          listenWhen: (prev, curr) =>
              prev.pois != curr.pois || prev.status != curr.status,
          listener: (context, state) {
            if (state.status == ViewportSearchStatus.success) {
              _symbolManager.renderPoiList(_mapController, state.pois);
            } else if (state.status == ViewportSearchStatus.error &&
                state.errorMessageKey != null) {
              showError(tr(state.errorMessageKey!));
            }
          },
        ),
        BlocListener<RoutePreviewCubit, RoutePreviewState>(
          listenWhen: (prev, curr) =>
              prev.status != curr.status ||
              prev.routeResult != curr.routeResult,
          listener: (context, state) {
            if (state.isSuccess && state.routeResult != null) {
              _routeManager.drawRoute(
                controller: _mapController,
                routeResult: state.routeResult!,
                origin: state.origin!,
                destination: state.destination!,
                destinationName: state.destinationName,
              );
              _routeManager.fitRouteBounds(
                controller: _mapController,
                routeResult: state.routeResult!,
                origin: state.origin,
                destination: state.destination,
              );
            } else if (state.isInitial) {
              _routeManager.clearRoute(_mapController);
            } else if (state.isError && state.errorMessageKey != null) {
              _routeManager.clearRoute(_mapController);
              showError(tr(state.errorMessageKey!));
            }
          },
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
          listener: (context, navState) {
            if (navState.isNavigating) {
              // 0. Nếu lộ trình thay đổi (khởi chạy hoặc reroute mới), vẽ lộ trình trước
              if (navState.currentRoute != null &&
                  navState.currentRoute != _renderedNavRoute &&
                  navState.origin != null &&
                  navState.destination != null) {
                _renderedNavRoute = navState.currentRoute;
                _routeManager.drawRoute(
                  controller: _mapController,
                  routeResult: navState.currentRoute!,
                  origin: navState.origin!,
                  destination: navState.destination!,
                  destinationName: navState.destinationName,
                );
              }

              // 1. Cập nhật camera dẫn đường 3D: Heading-up + Dynamic zoom theo tốc độ + Tilt 50
              if (navState.currentLat != null && navState.currentLon != null) {
                _cameraController.updateNavigationCamera(
                  controller: _mapController,
                  lat: navState.currentLat!,
                  lon: navState.currentLon!,
                  heading: navState.currentHeading,
                  speedKmh: navState.currentSpeedKmh,
                );

                // 2. Làm mờ đoạn đường đã đi qua (Dimming passed polyline)
                if (navState.currentRoute != null) {
                  _routeManager.updateNavigationProgress(
                    controller: _mapController,
                    rawPoints: navState.currentRoute!.points,
                    currentSegmentIndex: navState.currentSegmentIndex,
                  );
                }
              }
            } else if (navState.status == NavigationStatus.stopped ||
                navState.status == NavigationStatus.initial) {
              _renderedNavRoute = null;
              _routeManager.clearRoute(_mapController);
            }
          },
        ),
      ],
      child: BlocBuilder<MapDisplayCubit, MapDisplayState>(
        buildWhen: (prev, curr) =>
            prev.status != curr.status || prev.styleString != curr.styleString,
        builder: (context, state) {
          return Stack(
            children: [
              MapView(
                styleString: state.styleString,
                onMapCreated: (controller) {
                  _mapController = controller;
                  _mapController!.onSymbolTapped.add((symbol) {
                    final poi = _symbolManager.getPoiBySymbolId(symbol.id);
                    if (poi != null && mounted) {
                      widget.onPoiTapped(poi);
                    }
                  });
                  displayCubit.onMapCreated();
                },
                onStyleLoadedCallback: () {
                  _symbolManager.loadMarkerAssets(_mapController);
                  _routeManager.loadMarkerAssets(_mapController);
                  displayCubit.onStyleLoaded();
                },
                onCameraTrackingDismissed:
                    displayCubit.onCameraTrackingDismissed,
                onCameraMove: displayCubit.onCameraMove,
                onCameraIdle: _onCameraIdle,
                onMapLongClick: _onMapLongClick,
              ),
              if (state.status == MapDisplayStatus.loading)
                const Positioned.fill(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
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
        },
      ),
    );
  }
}
