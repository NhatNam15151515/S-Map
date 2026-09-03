import 'dart:async';
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
import 'package:s_map/services/services.dart';

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
  int _routeMarkerSyncGeneration = 0;
  int _memoryMarkerSyncGeneration = 0;
  String? _lastAppliedMapStyle;

  MapDisplayCubit get displayCubit => context.read<MapDisplayCubit>();
  ViewportSearchBloc get viewportBloc => context.read<ViewportSearchBloc>();
  RoutePreviewCubit get routePreviewCubit => context.read<RoutePreviewCubit>();

  bool get _hasActiveRouteOrNavigation {
    final previewState = routePreviewCubit.state;
    final navigationState = context.read<NavigationBloc>().state;
    return previewState.isLoading ||
        previewState.isSuccess ||
        navigationState.isNavigating;
  }

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

  Future<void> _applyMapStyle(String styleString) async {
    if (styleString.isEmpty || styleString == _lastAppliedMapStyle) return;

    final controller = _mapController;
    if (controller == null) return;

    _lastAppliedMapStyle = styleString;
    try {
      // Update the existing native map so its camera, location dot and
      // texture surface stay in place while the base tiles change.
      await controller.setStyle(styleString);
    } catch (error, stack) {
      _lastAppliedMapStyle = null;
      DLog.warning('⚠️ [Map] Không thể áp dụng style bản đồ: $error', stack);
    }
  }

  void _onSymbolTapped(Symbol symbol) {
    if (_hasActiveRouteOrNavigation || !mounted) return;
    final poi = _symbolManager.getPoiBySymbolId(symbol.id);
    if (poi != null) {
      // Resolve by the native symbol id, never by approximate coordinates.
      // Several POIs can be close together or share a building coordinate.
      widget.onPoiTapped(poi);
    }
  }

  void _onFeatureTapped(
    Point<double> point,
    LatLng latLng,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    // Native symbols have their own exact id-based callback above. The
    // generic feature callback also receives them, so do not resolve them a
    // second time through rendered-feature heuristics.
    if (annotation is Symbol || _hasActiveRouteOrNavigation || !mounted) {
      return;
    }
    unawaited(_handleRenderedFeatureTap(point, latLng));
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
  Future<void> setSelectedPoiMarker(PoiModel poi) {
    return _symbolManager.setSelectedPoiMarker(_mapController, poi);
  }

  /// Xóa ghim đơn lẻ khi đóng thẻ POI
  void clearSelectedPoiMarker({bool restoreSearchResults = true}) {
    _symbolManager.clearSelectedPoiMarker(
      _mapController,
      restoreSearchResults: restoreSearchResults,
    );
  }

  /// Ẩn search markers ngay khi người dùng bắt đầu mở chỉ đường.
  /// Danh sách POI vẫn được MapSymbolManager giữ lại để restore sau đó.
  Future<void> hideSearchResultMarkers() {
    return _symbolManager.hideSearchResultMarkers(_mapController);
  }

  Future<void> clearSearchResults() {
    return _symbolManager.clearSearchResults(_mapController);
  }

  /// Lưu snapshot kết quả mà không render thêm marker native.
  void cacheSearchResultPois(List<PoiModel> pois) {
    _symbolManager.cacheSearchResultPois(pois);
  }

  /// Xóa sạch toàn bộ ghim trên bản đồ
  void clearAll() {
    _symbolManager.clearAll(_mapController);
  }

  /// Chỉ hiển thị các POI có ý nghĩa cá nhân với người dùng: đã lưu hoặc đã
  /// thực sự đến. Các POI nền đại trà đã bị tắt trong offline style.
  Future<void> refreshMemoryMarkers() async {
    final generation = ++_memoryMarkerSyncGeneration;
    final favorites = context.read<FavoritesCubit>().state.favorites;
    List<PoiModel> visited = const [];
    try {
      visited = await VisitedPoiServiceImpl.instance.getVisitedPois();
    } catch (e, stack) {
      DLog.warning('⚠️ Không thể tải POI đã đến để render marker: $e', stack);
    }
    if (!mounted || generation != _memoryMarkerSyncGeneration) return;

    final merged = <String, PoiModel>{};
    for (final poi in [...favorites, ...visited]) {
      // Favorites and visited history may identify the same physical POI
      // differently; use coordinates for the visual marker identity.
      final key =
          'loc:${poi.lat.toStringAsFixed(6)}:${poi.lon.toStringAsFixed(6)}';
      // Keep the richer favorite record when the same destination also
      // appears in visit history (visited fallback records may only contain
      // coordinates and a generic category).
      merged.putIfAbsent(key, () => poi);
    }
    await _symbolManager.renderMemoryPois(
      _mapController,
      merged.values.toList(),
    );
  }

  /// Xử lý tap trên bản đồ: kiểm tra xem có tap vào marker không
  Future<void> _onMapClick(Point<double> point, LatLng latLng) async {
    // Route preview/navigation đang giữ quyền tương tác với map. Không mở
    // POI mới rồi vô tình tạo lại selected red marker trên route.
    if (_hasActiveRouteOrNavigation) return;

    final poi =
        _symbolManager.getPoiAtLocation(latLng.latitude, latLng.longitude);
    if (poi != null && mounted) {
      widget.onPoiTapped(poi);
      return;
    }

    // POI tìm kiếm của app nằm ở native symbol; các địa điểm có sẵn trên bản
    // đồ lại nằm trong vector tile. Query rendered features để cả hai loại
    // điểm đều đi qua cùng callback mở marker/bottom sheet.
    await _handleRenderedFeatureTap(point, latLng);
  }

  Future<void> _handleRenderedFeatureTap(
    Point<double> point,
    LatLng latLng,
  ) async {
    if (_hasActiveRouteOrNavigation || !mounted) return;
    final renderedPoi = await _queryRenderedPoi(point, latLng);
    if (renderedPoi != null && mounted) {
      widget.onPoiTapped(renderedPoi);
    }
  }

  @override
  void dispose() {
    _mapController?.onSymbolTapped.remove(_onSymbolTapped);
    _mapController?.onFeatureTapped.remove(_onFeatureTapped);
    super.dispose();
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
        if (raw != null && raw.toString().trim().isNotEmpty) {
          return raw.toString();
        }
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

  /// Hiển thị danh sách kết quả tìm kiếm và tùy chọn fit camera bao quanh.
  void showSearchResults(
    List<PoiModel> pois, {
    bool fitBounds = true,
  }) {
    _symbolManager.showSearchResults(
      _mapController,
      pois,
      fitBounds: fitBounds,
    );
  }

  /// Chuyển tiếp sự kiện chạm giữ (Long Press) trên bản đồ trực tiếp sang Cubit
  void _onMapLongClick(Point<double> point, LatLng latLng) {
    DLog.info(
        '👆 [Map] Long press detected at: (${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)})');
    hideSearchResultMarkers();
    routePreviewCubit.previewRouteToCoordinate(latLng);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<FavoritesCubit, FavoritesState>(
          listenWhen: (prev, curr) => prev.favorites != curr.favorites,
          listener: (context, state) {
            unawaited(refreshMemoryMarkers());
          },
        ),
        BlocListener<MapDisplayCubit, MapDisplayState>(
          listenWhen: (prev, curr) =>
              prev.cameraAction != curr.cameraAction ||
              prev.selectedPoi != curr.selectedPoi ||
              prev.status != curr.status ||
              prev.styleString != curr.styleString,
          listener: (context, state) async {
            _applyMapStyle(state.styleString);
            if (state.cameraAction != null) {
              handleCameraAction(state.cameraAction!);
            }
            if (state.selectedPoi != null) {
              await setSelectedPoiMarker(state.selectedPoi!);
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
            // Khi route preview/dẫn đường đang active, camera có thể làm
            // viewport search phát sinh state mới. Không render lại các
            // search marker trong giai đoạn này; route flow sẽ khôi phục
            // danh sách cũ sau khi kết thúc.
            if (_hasActiveRouteOrNavigation) return;

            if (state.status == ViewportSearchStatus.success) {
              if (state.selectedCategory == CategoryConstants.all) {
                if (state.pois.length == 1) {
                  // Một kết quả sẽ được Home chọn và render bằng selected
                  // marker; chỉ cache snapshot để không tạo hai pin chồng
                  // lên nhau.
                  _symbolManager.cacheSearchResultPois(state.pois);
                } else {
                  _symbolManager.renderPoiList(_mapController, state.pois);
                }
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
          listener: (context, state) async {
            final syncGeneration = ++_routeMarkerSyncGeneration;

            if (state.isLoading || state.isSuccess) {
              // Chỉ gỡ search symbols. Destination marker vẫn do
              // MapRouteManager vẽ riêng sau khi route tính xong.
              await _symbolManager.hideSearchResultMarkers(_mapController);
              if (!mounted || syncGeneration != _routeMarkerSyncGeneration) {
                return;
              }
            }

            if (state.isSuccess && state.currentRoute != null) {
              await _routeManager.drawRoute(
                controller: _mapController,
                routeResult: state.currentRoute!,
                origin: state.origin!,
                destination: state.destination!,
                destinationName: state.destinationName,
                alternativeRoutes: state.alternativeRoutes,
                selectedRouteIndex: state.selectedRouteIndex,
              );
              if (!mounted || syncGeneration != _routeMarkerSyncGeneration) {
                return;
              }
              _routeManager.fitRouteBounds(
                controller: _mapController,
                routeResult: state.currentRoute!,
                origin: state.origin,
                destination: state.destination,
              );
            } else if (state.isInitial || state.isError) {
              await _routeManager.clearRoute(_mapController);
              if (!mounted || syncGeneration != _routeMarkerSyncGeneration) {
                return;
              }

              // Nếu navigation vẫn đang chạy thì search markers phải tiếp
              // tục ẩn; NavigationListener sẽ khôi phục khi thật sự thoát.
              if (!_hasActiveRouteOrNavigation) {
                await _symbolManager.restoreSearchResultMarkers(_mapController);
              }

              if (state.isError && state.errorMessageKey != null) {
                showError(tr(state.errorMessageKey!));
              }
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
                await _symbolManager.hideSearchResultMarkers(_mapController);
                if (!mounted || gen != _navListenerGeneration) return;
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

              // 1. Cập nhật camera: chỉ khi user đang follow (chưa kéo map ra)
              if (navState.currentLat != null && navState.currentLon != null) {
                if (displayCubit.state.isFollowingUser) {
                  _cameraController.updateNavigationCamera(
                    controller: _mapController,
                    lat: navState.displayLat ?? navState.currentLat!,
                    lon: navState.displayLon ?? navState.currentLon!,
                    gpsHeading: navState.currentHeading,
                    compassHeading: displayCubit.state.compassHeading,
                    speedKmh: navState.currentSpeedKmh,
                  );
                }

                // 2. Làm mờ đoạn đường đã đi qua (luôn thực hiện)
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
              await _routeManager.clearRoute(_mapController);
              if (!mounted || gen != _navListenerGeneration) return;

              // Route preview có thể vẫn còn mở sau khi stop navigation;
              // chỉ restore khi cả hai chế độ route đều đã kết thúc.
              if (!_hasActiveRouteOrNavigation) {
                await _symbolManager.restoreSearchResultMarkers(_mapController);
              }
            } else if (navState.status == NavigationStatus.arrived) {
              await refreshMemoryMarkers();
            }
          },
        ),
      ],
      child: BlocBuilder<MapDisplayCubit, MapDisplayState>(
        buildWhen: (prev, curr) =>
            prev.status != curr.status ||
            (prev.styleString != curr.styleString && _mapController == null),
        builder: (context, state) {
          return BlocBuilder<NavigationBloc, NavigationState>(
            buildWhen: (prev, curr) =>
                prev.isNavigating != curr.isNavigating,
            builder: (context, navState) {
              final isNavigating = navState.isNavigating;
              return Stack(
            children: [
              Listener(
                behavior: HitTestBehavior.translucent,
                onPointerMove: (event) {
                  // Khi đang dẫn đường và người dùng vuốt/xoay bản đồ với khoảng cách > 2px:
                  // Ngay lập tức tạm dừng follow để người dùng thoải mái lướt xem đường
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
                onMapCreated: (controller) {
                  _mapController = controller;
                  controller.onSymbolTapped.add(_onSymbolTapped);
                  controller.onFeatureTapped.add(_onFeatureTapped);
                  _lastAppliedMapStyle = state.styleString;
                  displayCubit.onMapCreated();
                },
                onStyleLoadedCallback: () async {
                  final navigationBloc = context.read<NavigationBloc>();
                  _symbolManager.resetAssetLoaded();
                  _routeManager.resetAssetLoaded();
                  await _symbolManager.loadMarkerAssets(_mapController,
                      force: true);
                  await _symbolManager.initLayers(_mapController);
                  await _routeManager.loadMarkerAssets(_mapController,
                      force: true);
                  if (!mounted) return;

                  await refreshMemoryMarkers();

                  // 1. Khôi phục POI markers và selected POI marker (nếu có
                  // category/search đang active). Await để không tranh chấp
                  // với listener vừa nhận trạng thái style mới.
                  final viewportState = viewportBloc.state;
                  final previewState = routePreviewCubit.state;
                  final currentNavigationState = navigationBloc.state;
                  final routeOrNavigationActive =
                      previewState.isLoading ||
                      previewState.isSuccess ||
                      currentNavigationState.isNavigating;
                  if (!routeOrNavigationActive &&
                      viewportState.status == ViewportSearchStatus.success &&
                      viewportState.selectedCategory != CategoryConstants.all &&
                      viewportState.pois.isNotEmpty) {
                    await _symbolManager.renderPoiList(
                      _mapController,
                      viewportState.pois,
                    );
                  }
                  if (!routeOrNavigationActive &&
                      displayCubit.state.selectedPoi != null) {
                    await setSelectedPoiMarker(displayCubit.state.selectedPoi!);
                  }

                  _lastAppliedMapStyle = displayCubit.state.styleString;
                  await displayCubit.onStyleLoaded();

                  // 2. Khôi phục Route Preview nếu đang mở
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
                  if (!mounted) return;
                  final navState = navigationBloc.state;
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
          );
        },
      ),
    );
  }
}
