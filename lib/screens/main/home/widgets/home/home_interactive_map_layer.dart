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
import 'package:s_map/constants/constants.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/repos/repos.dart';
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
  final IPoiRepository _poiRepository = PoiRepositoryImpl();
  RouteResult? _renderedNavRoute;
  int _navListenerGeneration = 0;

  MapDisplayCubit get displayCubit => context.read<MapDisplayCubit>();
  ViewportSearchBloc get viewportBloc => context.read<ViewportSearchBloc>();
  RoutePreviewCubit get routePreviewCubit => context.read<RoutePreviewCubit>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (displayCubit.state.isNightMode != isDark) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && displayCubit.state.isNightMode != isDark) {
          displayCubit.updateThemeMode(isDark);
        }
      });
    }
  }

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
        // Không tự động quét ngẫu nhiên tất cả các loại POI khi vừa mở bản đồ
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

  /// Xóa sạch toàn bộ ghim trên bản đồ
  void clearAll() {
    _symbolManager.clearAll(_mapController);
  }

  /// Xử lý tap trên bản đồ: kiểm tra xem có tap vào marker không
  Future<void> _onMapClick(Point<double> point, LatLng latLng) async {
    final poi =
        _symbolManager.getPoiAtLocation(latLng.latitude, latLng.longitude);
    if (poi != null && mounted) {
      widget.onPoiTapped(poi);
      return;
    }

    // Các POI tìm kiếm của app nằm ở GeoJSON layer riêng; các địa điểm có
    // sẵn trên bản đồ lại nằm trong vector tile. Query rendered features để
    // cả hai loại điểm đều đi qua cùng callback mở marker/bottom sheet.
    final renderedPoi = await _queryRenderedPoi(point, latLng);
    if (renderedPoi != null && mounted) {
      widget.onPoiTapped(renderedPoi);
    }
  }

  Future<PoiModel?> _queryRenderedPoi(
      Point<double> point, LatLng latLng) async {
    final controller = _mapController;
    if (controller == null) return null;

    try {
      final features =
          await controller.queryRenderedFeatures(point, const [], null);
      final candidates = <PoiModel>[];
      for (final rawFeature in features) {
        if (rawFeature is! Map) continue;
        final rawProperties = rawFeature['properties'];
        if (rawProperties is! Map) continue;
        final properties = Map<String, dynamic>.from(rawProperties);
        final poi = _poiFromRenderedProperties(properties, latLng);
        if (poi != null) candidates.add(poi);
      }

      if (candidates.isNotEmpty) {
        candidates
            .sort((a, b) => _poiFeatureScore(b).compareTo(_poiFeatureScore(a)));
        return await _enrichRenderedPoi(candidates.first);
      }

      // Một số tile chỉ chứa hình học/label, không mang đủ metadata POI.
      // Tra cứu thêm trong DB offline quanh vị trí chạm để lấy thông tin đầy đủ.
      const delta = 0.0008; // khoảng 80–90 m quanh điểm chạm
      final nearby = await _poiRepository.searchInBounds(
        minLat: latLng.latitude - delta,
        maxLat: latLng.latitude + delta,
        minLon: latLng.longitude - delta,
        maxLon: latLng.longitude + delta,
        limit: 10,
      );
      if (nearby.isEmpty) return null;
      nearby.sort(
          (a, b) => _distanceTo(a, latLng).compareTo(_distanceTo(b, latLng)));
      return nearby.first;
    } catch (e, stack) {
      DLog.warning(
          '⚠️ [Map] Không đọc được feature tại vị trí chạm: $e', stack);
      return null;
    }
  }

  PoiModel? _poiFromRenderedProperties(
    Map<String, dynamic> properties,
    LatLng fallbackLocation,
  ) {
    String value(List<String> keys) {
      for (final key in keys) {
        final raw = properties[key];
        if (raw != null && raw.toString().trim().isNotEmpty)
          return raw.toString();
      }
      return '';
    }

    final name = value(['name:vi', 'name', 'name_vi', 'name:en']);
    final category = value([
      'category',
      'amenity',
      'tourism',
      'shop',
      'leisure',
      'historic',
      'public_transport',
      'place',
    ]);
    if (name.isEmpty ||
        (category.isEmpty &&
            value(['address', 'addr:street', 'street']).isEmpty)) {
      return null;
    }

    final idValue = value(['id', 'osm_id', '@id']);
    return PoiModel(
      id: int.tryParse(idValue),
      osmId: idValue.isEmpty ? null : idValue,
      name: name,
      nameAscii: AppUtils.instance.toAscii(name),
      category: category.isEmpty ? 'place' : category,
      subCategory: value(['sub_category', 'subclass', 'type']),
      lat: fallbackLocation.latitude,
      lon: fallbackLocation.longitude,
      address: value(['address', 'addr:full']),
      street: value(['street', 'addr:street']),
      housenumber: value(['housenumber', 'addr:housenumber']),
      city: value(['city', 'addr:city']),
    );
  }

  int _poiFeatureScore(PoiModel poi) {
    final category = (poi.category ?? '').toLowerCase();
    return category == 'place' ? 1 : 3;
  }

  Future<PoiModel> _enrichRenderedPoi(PoiModel poi) async {
    final nearby = await _poiRepository.searchInBounds(
      minLat: poi.lat - 0.0008,
      maxLat: poi.lat + 0.0008,
      minLon: poi.lon - 0.0008,
      maxLon: poi.lon + 0.0008,
      query: poi.name,
      limit: 5,
    );
    if (nearby.isEmpty) return poi;
    nearby.sort((a, b) => _distanceTo(a, LatLng(poi.lat, poi.lon))
        .compareTo(_distanceTo(b, LatLng(poi.lat, poi.lon))));
    return nearby.first;
  }

  double _distanceTo(PoiModel poi, LatLng location) {
    return AppUtils.instance.calculateDistance(
      poi.lat,
      poi.lon,
      location.latitude,
      location.longitude,
    );
  }

  /// Hiển thị danh sách kết quả tìm kiếm và fit camera bao quanh
  void showSearchResults(List<PoiModel> pois) {
    _symbolManager.showSearchResults(_mapController, pois);
  }

  /// Chuyển tiếp sự kiện chạm giữ (Long Press) trên bản đồ trực tiếp sang Cubit
  void _onMapLongClick(Point<double> point, LatLng latLng) {
    DLog.info(
        '👆 [Map] Long press detected at: (${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)})');
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
            } else if (state.selectedPoi == null &&
                _symbolManager.selectedPoi != null) {
              clearSelectedPoiMarker();
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
              if (state.selectedCategory == CategoryConstants.all) {
                _symbolManager.renderPoiList(_mapController, state.pois);
              }
            } else if (state.status == ViewportSearchStatus.empty) {
              if (state.selectedCategory == CategoryConstants.all) {
                _symbolManager.renderPoiList(_mapController, const []);
              }
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
          listener: (context, navState) async {
            final gen = ++_navListenerGeneration;
            if (navState.isNavigating) {
              // 0. Nếu lộ trình thay đổi (khởi chạy hoặc reroute mới), vẽ lộ trình trước
              if (navState.currentRoute != null &&
                  navState.currentRoute != _renderedNavRoute &&
                  navState.origin != null &&
                  navState.destination != null) {
                final isSuccess = await _routeManager.drawRoute(
                  controller: _mapController,
                  routeResult: navState.currentRoute!,
                  origin: navState.origin!,
                  destination: navState.destination!,
                  destinationName: navState.destinationName,
                );
                if (!mounted || gen != _navListenerGeneration) return;
                if (isSuccess) {
                  _renderedNavRoute = navState.currentRoute;
                }
              }

              if (!mounted || gen != _navListenerGeneration) return;

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
                if (navState.currentRoute != null &&
                    navState.currentRoute == _renderedNavRoute &&
                    gen == _navListenerGeneration) {
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
                key: const Key('map_view_main'),
                styleString: state.styleString,
                onMapCreated: (controller) {
                  _mapController = controller;
                  displayCubit.onMapCreated();
                },
                onStyleLoadedCallback: () async {
                  _symbolManager.resetAssetLoaded();
                  _routeManager.resetAssetLoaded();
                  await _symbolManager.loadMarkerAssets(_mapController,
                      force: true);
                  await _symbolManager.initLayers(_mapController);
                  await _symbolManager.renderSovereigntySymbols(_mapController);
                  await _routeManager.loadMarkerAssets(_mapController,
                      force: true);
                  displayCubit.onStyleLoaded();

                  if (!mounted) return;

                  // 1. Khôi phục POI markers và selected POI marker (nếu có category/search đang active)
                  final viewportState = viewportBloc.state;
                  if (viewportState.status == ViewportSearchStatus.success &&
                      viewportState.selectedCategory != CategoryConstants.all &&
                      viewportState.pois.isNotEmpty) {
                    _symbolManager.renderPoiList(
                        _mapController, viewportState.pois);
                  }
                  if (displayCubit.state.selectedPoi != null) {
                    setSelectedPoiMarker(displayCubit.state.selectedPoi!);
                  }

                  // 2. Khôi phục Route Preview nếu đang mở
                  final previewState = routePreviewCubit.state;
                  if (previewState.isSuccess &&
                      previewState.routeResult != null &&
                      previewState.origin != null &&
                      previewState.destination != null) {
                    _routeManager.drawRoute(
                      controller: _mapController,
                      routeResult: previewState.routeResult!,
                      origin: previewState.origin!,
                      destination: previewState.destination!,
                      destinationName: previewState.destinationName,
                    );
                  }

                  // 3. Khôi phục Navigation Polyline nếu đang dẫn đường
                  if (!context.mounted) return;
                  final navState = context.read<NavigationBloc>().state;
                  if (navState.isNavigating &&
                      navState.currentRoute != null &&
                      navState.origin != null &&
                      navState.destination != null) {
                    _routeManager.drawRoute(
                      controller: _mapController,
                      routeResult: navState.currentRoute!,
                      origin: navState.origin!,
                      destination: navState.destination!,
                      destinationName: navState.destinationName,
                    );
                    _renderedNavRoute = navState.currentRoute;
                  }
                },
                onCameraTrackingDismissed:
                    displayCubit.onCameraTrackingDismissed,
                onCameraMove: displayCubit.onCameraMove,
                onCameraIdle: _onCameraIdle,
                onMapClick: _onMapClick,
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
