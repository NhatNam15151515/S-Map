import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/repos/repos.dart';
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
    this.areaSearchResolver,
  });

  final AreaSearchDestinationResolver? areaSearchResolver;

  @override
  State<RouteDrawingScreen> createState() => _RouteDrawingScreenState();
}

class _RouteDrawingScreenState extends State<RouteDrawingScreen> {
  final GlobalKey<RouteDrawingMapLayerState> _mapLayerKey = GlobalKey();

  AppCubit? _appCubit;
  late final RouteDrawingBloc _drawingBloc;
  late final SavedRoutesCubit _savedRoutesCubit;
  late final MapDisplayCubit _mapDisplayCubit;
  late final RouteDrawingOriginController _originController;
  late final RouteDrawingDestinationController _destController;

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

    _originController = RouteDrawingOriginController(
      mapDisplayCubit: _mapDisplayCubit,
      drawingBloc: _drawingBloc,
      onStateChanged: () {
        if (mounted) setState(() {});
      },
    );

    _destController = RouteDrawingDestinationController(
      mapDisplayCubit: _mapDisplayCubit,
      drawingBloc: _drawingBloc,
      areaSearchResolver:
          widget.areaSearchResolver ?? AreaSearchDestinationResolver(),
      onStateChanged: () {
        if (mounted) setState(() {});
      },
    );

    RouteDrawingPayloadInitializer(
      drawingBloc: _drawingBloc,
      originController: _originController,
      destController: _destController,
    ).initialize(
      payload: widget.payload,
      initialOrigin: widget.initialOrigin,
      initialDestination: widget.initialDestination,
      isMounted: () => mounted,
      setState: () => setState(() {}),
    );
  }

  AppCubit? _tryReadAppCubit() {
    try {
      return context.read<AppCubit>();
    } catch (_) {
      return null;
    }
  }

  void _handleMapTap(LatLng tappedLatLng) {
    if (_destController.isDestinationPickerActive) {
      _destController.setMarkerDestination(
        tappedLatLng,
        addToRoute: _drawingBloc.state.points.isNotEmpty,
      );
      return;
    }

    if (_drawingBloc.state.points.isEmpty &&
        _destController.markerDestination != null) {
      _drawingBloc.add(
        RouteDrawingEndpointsSelected(
          origin: RoutePoint(
            lat: tappedLatLng.latitude,
            lon: tappedLatLng.longitude,
          ),
          destination: RoutePoint(
            lat: _destController.markerDestination!.latitude,
            lon: _destController.markerDestination!.longitude,
          ),
        ),
      );
      return;
    }

    _drawingBloc.add(
      RouteDrawingPointTapped(
        lat: tappedLatLng.latitude,
        lon: tappedLatLng.longitude,
      ),
    );
  }

  void _handleAddPointAtCenter() {
    final center = _mapLayerKey.currentState?.currentCenter ??
        _mapDisplayCubit.state.center;
    if (center == null) return;
    HapticFeedback.lightImpact();

    if (_drawingBloc.state.points.isEmpty &&
        _destController.markerDestination != null) {
      _drawingBloc.add(
        RouteDrawingEndpointsSelected(
          origin: RoutePoint(lat: center.latitude, lon: center.longitude),
          destination: RoutePoint(
            lat: _destController.markerDestination!.latitude,
            lon: _destController.markerDestination!.longitude,
          ),
        ),
      );
      return;
    }

    _drawingBloc.add(
      RouteDrawingPointTapped(lat: center.latitude, lon: center.longitude),
    );
  }

  @override
  void dispose() {
    if (widget.drawingBloc == null) _drawingBloc.close();
    if (widget.savedRoutesCubit == null) _savedRoutesCubit.close();
    if (widget.mapDisplayCubit == null) _mapDisplayCubit.close();
    super.dispose();
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
        buildWhen: (prev, curr) =>
            prev.status != curr.status ||
            prev.pointCount != curr.pointCount ||
            prev.points != curr.points ||
            prev.segments != curr.segments ||
            prev.totalDistance != curr.totalDistance ||
            prev.totalTime != curr.totalTime ||
            prev.canUndo != curr.canUndo ||
            prev.canRedo != curr.canRedo ||
            prev.isStraightLineMode != curr.isStraightLineMode,
        builder: (context, state) {
          return Stack(
            children: [
              _buildMapLayer(),
              _buildCenterOverlay(state),
              RouteDrawingConnectedToolbar(
                state: state,
                destController: _destController,
                mapDisplayCubit: _mapDisplayCubit,
                drawingBloc: _drawingBloc,
                mapLayerKey: _mapLayerKey,
                onSetState: () => setState(() {}),
              ),
              RouteDrawingBottomCard(
                pointCount: state.pointCount,
                distanceMeters: state.totalDistance,
                durationMs: state.totalTime,
                isLoading: state.isLoading,
                isStraightLineMode: state.isStraightLineMode,
                onSavePressed: () =>
                    RouteDrawingActionCoordinator.showSaveRouteDialog(
                  context: context,
                  drawingBloc: _drawingBloc,
                ),
                onNavigatePressed: () =>
                    RouteDrawingActionCoordinator.startNavigationFromDrawnRoute(
                  context: context,
                  state: state,
                ),
              ),
              _buildTopBar(topPadding, context, state),
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

  Widget _buildMapLayer() {
    if (widget.mapLayerBuilder != null) return widget.mapLayerBuilder!();
    return RouteDrawingMapLayer(
      key: _mapLayerKey,
      isCrosshairActive: _destController.isCrosshairActive &&
          !_destController.isDestinationPickerActive,
      markerDestination: _destController.markerDestination,
      onMapTap: _handleMapTap,
    );
  }

  Widget _buildTopBar(
    double topPadding,
    BuildContext context,
    RouteDrawingState state,
  ) {
    return RouteDrawingWaypointPanel(
      topPadding: topPadding,
      points: state.points,
      segments: state.segments,
      onSavedRoutesPressed: () =>
          RouteDrawingActionCoordinator.showSavedRoutesSheet(
        context: context,
        drawingBloc: _drawingBloc,
        savedRoutesCubit: _savedRoutesCubit,
      ),
      onSearchDestinationPressed: () =>
          _destController.handleSearch(context, mounted),
      onReorder: (oldIndex, newIndex) {
        _drawingBloc.add(RouteDrawingReorderPoints(oldIndex, newIndex));
      },
      onRemovePoint: (index) {
        _drawingBloc.add(RouteDrawingRemovePoint(index));
      },
      onToggleSegmentStraightLine: (segmentIndex) {
        _drawingBloc
            .add(RouteDrawingToggleSegmentStraightLine(segmentIndex));
      },
    );
  }

  Widget _buildCenterOverlay(RouteDrawingState state) {
    if (_destController.isDestinationPickerActive) {
      return RouteDrawingDestinationPickerOverlay(
        onConfirm: () {
          final center = _mapLayerKey.currentState?.currentCenter ??
              _mapDisplayCubit.state.center ??
              MapConstants.defaultLocation;
          _destController.handleConfirmPicker(center);
        },
        onCancel: _destController.handleCancelPicker,
        bottomOffset: MediaQuery.paddingOf(context).bottom +
            (state.points.length >= 2 ? 200 : 140),
      );
    }
    if (_destController.isCrosshairActive) {
      return RouteDrawingCrosshairOverlay(
        isLoading: state.isLoading,
        hasPoints: state.points.isNotEmpty,
        onAddPoint: _handleAddPointAtCenter,
        bottomOffset: MediaQuery.paddingOf(context).bottom +
            (state.points.length >= 2 ? 190 : 130),
      );
    }
    return const SizedBox.shrink();
  }
}
