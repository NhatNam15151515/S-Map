import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/repos/repos.dart';
import 'package:s_map/routers/app_routes.dart';
import 'widgets/widgets.dart';

class RouteDrawingScreen extends StatefulWidget {
  final RouteDrawingBloc? drawingBloc;
  final SavedRoutesCubit? savedRoutesCubit;
  final MapDisplayCubit? mapDisplayCubit;
  final RouteDrawingPayload? payload;
  final LatLng? initialOrigin;
  final LatLng? initialDestination;
  final String? destinationName;

  /// Optional builder to replace the map layer widget (for testing).
  final Widget Function()? mapLayerBuilder;

  const RouteDrawingScreen({
    super.key,
    this.drawingBloc,
    this.savedRoutesCubit,
    this.mapDisplayCubit,
    this.payload,
    this.initialOrigin,
    this.initialDestination,
    this.destinationName,
    this.mapLayerBuilder,
  });

  @override
  State<RouteDrawingScreen> createState() => _RouteDrawingScreenState();
}

class _RouteDrawingScreenState extends State<RouteDrawingScreen> {
  final GlobalKey<RouteDrawingMapLayerState> _mapLayerKey = GlobalKey();

  AppCubit? _appCubit;
  late final RouteDrawingBloc _drawingBloc;
  late final SavedRoutesCubit _savedRoutesCubit;
  late final MapDisplayCubit _mapDisplayCubit;

  bool _isMyLocationOriginActive = false;
  bool _isResolvingMyLocationOrigin = false;
  bool _isMarkerDestinationActive = false;
  bool _isDestinationPickerActive = true;
  bool _isCrosshairActive = true;
  LatLng? _markerDestination;

  @override
  void initState() {
    super.initState();
    _appCubit = _tryReadAppCubit();
    _mapDisplayCubit = widget.mapDisplayCubit ??
        MapDisplayCubit(isDarkMode: _appCubit?.state.isDarkMode);
    _drawingBloc = widget.drawingBloc ??
        RouteDrawingBloc(
          routingRepository: AppReposProvider.instance.routingRepos,
          customRouteRepository: AppReposProvider.instance.customRouteRepos,
        );
    _savedRoutesCubit = widget.savedRoutesCubit ??
        SavedRoutesCubit(
          customRouteRepository: AppReposProvider.instance.customRouteRepos,
        );

    final payload = widget.payload;
    final initialRoute = payload?.initialRoute;
    final effectiveOrigin = widget.initialOrigin ?? payload?.initialOrigin;
    _markerDestination = widget.initialDestination ??
        payload?.initialDestination ??
        (payload?.destinationPoi != null
            ? LatLng(payload!.destinationPoi!.lat, payload.destinationPoi!.lon)
            : null);
    _isDestinationPickerActive = _markerDestination == null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (initialRoute != null) {
        _drawingBloc.add(RouteDrawingLoadRoute(initialRoute));
        return;
      }
      if (effectiveOrigin != null) {
        _drawingBloc.add(
          RouteDrawingEndpointsSelected(
            origin: RoutePoint(
              lat: effectiveOrigin.latitude,
              lon: effectiveOrigin.longitude,
            ),
            destination: _markerDestination == null
                ? null
                : RoutePoint(
                    lat: _markerDestination!.latitude,
                    lon: _markerDestination!.longitude,
                  ),
          ),
        );
        setState(() {
          _isMyLocationOriginActive = true;
          _isMarkerDestinationActive = _markerDestination != null;
        });
      }
    });
  }

  AppCubit? _tryReadAppCubit() {
    try {
      return context.read<AppCubit>();
    } catch (_) {
      // RouteDrawingScreen cũng được dùng độc lập trong widget tests/previews.
      return null;
    }
  }

  Future<void> _handleToggleMyLocationOrigin() async {
    if (_isResolvingMyLocationOrigin) return;

    // Đây là một nút chọn trạng thái, không phải một luồng GPS chạy nền.
    // Cho phép tắt ngay trạng thái active mà không gọi lại permission/GPS.
    if (_isMyLocationOriginActive) {
      setState(() => _isMyLocationOriginActive = false);
      return;
    }

    final mapState = _mapDisplayCubit.state;
    final cachedPosition =
        mapState.hasRealLocation ? mapState.currentPosition : null;
    if (cachedPosition != null) {
      _addMyLocationOrigin(cachedPosition);
      return;
    }

    setState(() => _isResolvingMyLocationOrigin = true);
    try {
      // Khi chưa có tọa độ thật, acquireCurrentPosition() chỉ thực hiện một
      // request; LocationService sẽ tự mở prompt bật GPS/quyền nếu cần.
      final currentPos = await _mapDisplayCubit.acquireCurrentPosition();
      if (currentPos != null && mounted) {
        _addMyLocationOrigin(currentPos);
      }
    } finally {
      if (mounted) {
        setState(() => _isResolvingMyLocationOrigin = false);
      }
    }
  }

  void _addMyLocationOrigin(LatLng currentPos) {
    if (!mounted || _drawingBloc.state.points.isNotEmpty) return;

    setState(() {
      _isMyLocationOriginActive = true;
      // Destination đã được truyền từ POI/search thì luôn nằm sau origin.
      _isMarkerDestinationActive = _markerDestination != null;
    });

    _drawingBloc.add(
      RouteDrawingEndpointsSelected(
        origin: RoutePoint(
          lat: currentPos.latitude,
          lon: currentPos.longitude,
        ),
        destination: _markerDestination == null
            ? null
            : RoutePoint(
                lat: _markerDestination!.latitude,
                lon: _markerDestination!.longitude,
              ),
      ),
    );
  }

  void _handleLocateMe() {
    _mapDisplayCubit.locateMe();
  }

  Future<void> _handleSearchDestination() async {
    final mapState = _mapDisplayCubit.state;
    final searchCenter = mapState.currentPosition ?? mapState.center;
    final result = await context.push<dynamic>(
      AppRoutes.search,
      extra: searchCenter,
    );
    if (!mounted) return;

    PoiModel? poi;
    if (result is SearchResultPayload && result.isArea) {
      poi = await _resolveAreaSearchDestination(result);
    } else if (result is SearchResultPayload && result.isSingle) {
      poi = result.selectedPoi;
    } else if (result is PoiModel) {
      poi = result;
    }
    if (poi == null) return;

    final destination = LatLng(poi.lat, poi.lon);
    _mapDisplayCubit.selectPoi(poi);
    _setMarkerDestination(destination, addToRoute: true);
  }

  /// SearchScreen dùng area intent cho Home. Route drawing vẫn cần một POI
  /// cụ thể, nên resolve intent thành địa điểm phù hợp nhất tại đây thay vì
  /// để payload mới làm mất chức năng chọn đích.
  Future<PoiModel?> _resolveAreaSearchDestination(
    SearchResultPayload payload,
  ) async {
    final center = payload.searchCenter ??
        _mapDisplayCubit.state.center ??
        MapConstants.defaultLocation;
    final query = payload.submittedQuery?.trim();
    try {
      List<PoiModel> candidates;
      if (query != null && query.isNotEmpty) {
        candidates = await PoiRepositoryImpl().search(query, limit: 50);
      } else if (payload.searchCategory != null &&
          payload.searchCategory!.trim().isNotEmpty) {
        final bounds = MapConstants.boundsFromCenter(center, 1200.0);
        candidates = await PoiRepositoryImpl().searchInBounds(
          minLat: bounds.southwest.latitude,
          maxLat: bounds.northeast.latitude,
          minLon: bounds.southwest.longitude,
          maxLon: bounds.northeast.longitude,
          category: payload.searchCategory,
          limit: 50,
        );
      } else {
        return null;
      }

      final ranked = SearchResultRanker.rank(
        candidates,
        center: center,
        query: query,
        limit: 1,
      );
      return ranked.isEmpty ? null : ranked.first;
    } catch (_) {
      return null;
    }
  }

  void _setMarkerDestination(LatLng destination, {bool addToRoute = false}) {
    if (!mounted) return;
    setState(() {
      _markerDestination = destination;
      _isDestinationPickerActive = false;
      _isMarkerDestinationActive = true;
    });

    if (addToRoute && _drawingBloc.state.points.isNotEmpty) {
      _drawingBloc.add(
        RouteDrawingPointTapped(
          lat: destination.latitude,
          lon: destination.longitude,
        ),
      );
    }
  }

  void _handleToggleMarkerDestination() {
    final center = _mapDisplayCubit.state.center;
    if (_markerDestination == null && center == null) return;

    if (_markerDestination == null) {
      _setMarkerDestination(
        center!,
        addToRoute: _drawingBloc.state.points.isNotEmpty,
      );
      return;
    }

    if (_drawingBloc.state.points.isEmpty) {
      // Giữ đích ở trạng thái chờ; khi chọn origin, BLoC sẽ tạo cả cặp
      // endpoint đúng thứ tự thay vì biến destination thành điểm bắt đầu.
      setState(() => _isMarkerDestinationActive = true);
      return;
    }

    if (_isMarkerDestinationActive) {
      if (_drawingBloc.state.points.length >= 2) {
        _drawingBloc.add(const RouteDrawingUndoLastPoint());
      }
      setState(() {
        _markerDestination = null;
        _isMarkerDestinationActive = false;
        _isDestinationPickerActive = true;
      });
      return;
    }
    setState(() => _isMarkerDestinationActive = true);
    _drawingBloc.add(
      RouteDrawingPointTapped(
        lat: _markerDestination!.latitude,
        lon: _markerDestination!.longitude,
      ),
    );
  }

  void _handleRemoveMarkerDestination() {
    final state = _drawingBloc.state;
    // Đích đã chọn được thêm như điểm cuối thì hoàn tác đúng điểm đó,
    // không đụng vào các waypoint phía trước.
    if (_isMarkerDestinationActive && state.points.length >= 2) {
      _drawingBloc.add(const RouteDrawingUndoLastPoint());
    }
    setState(() {
      _markerDestination = null;
      _isMarkerDestinationActive = false;
      _isDestinationPickerActive = true;
    });
  }

  void _handleAddPointAtCenter() {
    final center = _mapLayerKey.currentState?.currentCenter ??
        _mapDisplayCubit.state.center;
    if (center == null) return;
    HapticFeedback.lightImpact();
    _drawingBloc.add(
      RouteDrawingPointTapped(
        lat: center.latitude,
        lon: center.longitude,
      ),
    );
  }

  void _handleReverseRoute() {
    HapticFeedback.mediumImpact();
    _drawingBloc.add(const RouteDrawingReverseRoute());
  }

  @override
  void dispose() {
    if (widget.drawingBloc == null) {
      _drawingBloc.close();
    }
    if (widget.savedRoutesCubit == null) {
      _savedRoutesCubit.close();
    }
    if (widget.mapDisplayCubit == null) {
      _mapDisplayCubit.close();
    }
    super.dispose();
  }

  void _handleSaveRoute(BuildContext context, RouteDrawingState state) {
    final now = DateTime.now();
    final defaultName = tr(
      LocaleKeys.route_drawing_ui_default_route_name,
      args: [DateFormat('dd/MM/yyyy HH:mm').format(now)],
    );

    SaveCustomRouteDialog.show(
      context,
      initialName: defaultName,
      onSave: (name, description) {
        _drawingBloc.add(
          RouteDrawingSaveRoute(
            name: name,
            description: description,
          ),
        );
      },
    );
  }

  void _handleNavigate(BuildContext context, RouteDrawingState state) {
    if (!state.hasRoute) return;

    final rawPoints = state.fullPolyline.map((p) => [p.lat, p.lon]).toList();
    final customName = tr(LocaleKeys.route_drawing_ui_custom_route_name);
    final followInstruction =
        tr(LocaleKeys.route_drawing_ui_follow_custom_route);
    final instructions = <RouteInstruction>[
      RouteInstruction(
        text: followInstruction,
        streetName: customName,
        distance: state.totalDistance,
        time: state.totalTime,
        sign: 0,
        points: rawPoints,
      ),
    ];

    final customRoute = RouteResult(
      isSuccess: true,
      distance: state.totalDistance,
      time: state.totalTime,
      points: rawPoints,
      instructions: instructions,
    );

    try {
      context.read<NavigationBloc>().add(
            StartNavigation(
              initialRoute: customRoute,
              origin: state.fullPolyline.first,
              destination: state.fullPolyline.last,
              destinationName: customName,
            ),
          );
    } catch (_) {}

    context.go(AppRoutes.home);
  }

  void _handleOpenSavedRoutes(BuildContext context) {
    SavedRoutesSheet.show(
      context,
      onRouteSelected: (route) {
        _drawingBloc.add(RouteDrawingLoadRoute(route));
      },
      onRouteDeleted: (id) {
        _savedRoutesCubit.deleteRoute(id);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return MultiBlocProvider(
      providers: [
        BlocProvider<MapDisplayCubit>.value(value: _mapDisplayCubit),
        BlocProvider<RouteDrawingBloc>.value(value: _drawingBloc),
        BlocProvider<SavedRoutesCubit>.value(value: _savedRoutesCubit),
      ],
      child: _buildThemeAwareContent(topPadding),
    );
  }

  Widget _buildThemeAwareContent(double topPadding) {
    final content = Scaffold(
      body: BlocBuilder<RouteDrawingBloc, RouteDrawingState>(
        builder: (context, state) {
          return Stack(
            children: [
              // 1. Map Layer
              if (widget.mapLayerBuilder != null)
                widget.mapLayerBuilder!()
              else
                RouteDrawingMapLayer(
                  key: _mapLayerKey,
                  isCrosshairActive: _isCrosshairActive,
                ),

              // 2. Floating Top Bar
              RouteDrawingTopBar(
                topPadding: topPadding,
                onSavedRoutesPressed: () => _handleOpenSavedRoutes(context),
                onSearchDestinationPressed: _handleSearchDestination,
              ),

              if (_isDestinationPickerActive)
                const IgnorePointer(
                  child: Center(
                    child: Icon(Icons.flag_rounded, size: 42),
                  ),
                )
              else if (_isCrosshairActive)
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    if (!state.isLoading) {
                      _handleAddPointAtCenter();
                    }
                  },
                  child: Center(
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.85),
                                width: 2.0,
                              ),
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.12),
                            ),
                          ),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).colorScheme.primary,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          // Reticle cross lines
                          Positioned(
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: 1.5,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 1.5,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 3. Floating Toolbar (Undo, Redo, Clear, Fit Bounds, Reverse, Crosshair, Origin/Dest Toggles)
              RouteDrawingFloatingToolbar(
                canUndo: state.canUndo,
                canRedo: state.canRedo,
                canClear: state.points.isNotEmpty,
                hasPoints: state.points.isNotEmpty,
                isMyLocationOrigin: _isMyLocationOriginActive,
                isResolvingMyLocation: _isResolvingMyLocationOrigin,
                isMarkerDestination: _isMarkerDestinationActive,
                hasMarkerDestination: true,
                onLocateMe: _handleLocateMe,
                onUndo: () =>
                    _drawingBloc.add(const RouteDrawingUndoLastPoint()),
                onRedo: () => _drawingBloc.add(const RouteDrawingRedoPoint()),
                onReverseRoute: _handleReverseRoute,
                canReverse: state.points.length >= 2,
                isCrosshairActive: _isCrosshairActive,
                onToggleCrosshair: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isCrosshairActive = !_isCrosshairActive);
                },
                onClear: () {
                  setState(() {
                    _isMyLocationOriginActive = false;
                    _isMarkerDestinationActive = false;
                  });
                  _drawingBloc.add(const RouteDrawingClearRoute());
                },
                isStraightLineMode: state.isStraightLineMode,
                onToggleStraightLineMode: () {
                  HapticFeedback.selectionClick();
                  _drawingBloc.add(const RouteDrawingToggleStraightLineMode());
                },
                onFitBounds: () => _mapLayerKey.currentState?.fitRouteBounds(),
                onToggleMyLocationOrigin: _handleToggleMyLocationOrigin,
                onToggleMarkerDestination: _handleToggleMarkerDestination,
                onRemoveMarkerDestination: _markerDestination != null
                    ? _handleRemoveMarkerDestination
                    : null,
              ),

              // 4. Center Crosshair Add Waypoint Floating Button
              if (_isCrosshairActive && !_isDestinationPickerActive)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: MediaQuery.paddingOf(context).bottom +
                      (state.points.length >= 2 ? 190 : 130),
                  child: Center(
                    child: ElevatedButton.icon(
                      key: const Key('route_drawing_add_point_center_btn'),
                      onPressed:
                          state.isLoading ? null : _handleAddPointAtCenter,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        elevation: 6,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        shadowColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.4),
                      ),
                      icon: const Icon(Icons.add_location_alt_rounded, size: 20),
                      label: Text(
                        state.points.isEmpty
                            ? tr(LocaleKeys.route_drawing_ui_center_add_start_point)
                            : tr(LocaleKeys.route_drawing_ui_center_add_next_point),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),

              // 5. Bottom Summary & Action Card
              RouteDrawingBottomCard(
                pointCount: state.pointCount,
                distanceMeters: state.totalDistance,
                durationMs: state.totalTime,
                isLoading: state.isLoading,
                isStraightLineMode: state.isStraightLineMode,
                onSavePressed: () => _handleSaveRoute(context, state),
                onNavigatePressed: () => _handleNavigate(context, state),
              ),
            ],
          );
        },
      ),
    );

    final appCubit = _appCubit;
    if (appCubit == null) return content;

    return BlocListener<AppCubit, AppState>(
      bloc: appCubit,
      listenWhen: (previous, current) =>
          previous.themeMode != current.themeMode ||
          previous.appStyle != current.appStyle,
      listener: (context, appState) {
        _mapDisplayCubit.updateMapTheme(isDarkMode: appState.isDarkMode);
      },
      child: content,
    );
  }
}
