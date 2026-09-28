import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/models/models.dart';
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
  late final RouteDrawingSession _session;

  RouteDrawingBloc get _drawingBloc => _session.drawingBloc;
  SavedRoutesCubit get _savedRoutesCubit => _session.savedRoutesCubit;
  MapDisplayCubit get _mapDisplayCubit => _session.mapDisplayCubit;
  RouteDrawingDestinationController get _destController =>
      _session.destinationController;

  @override
  void initState() {
    super.initState();
    _appCubit = _tryReadAppCubit();
    _session = RouteDrawingSession(
      drawingBloc: widget.drawingBloc,
      savedRoutesCubit: widget.savedRoutesCubit,
      mapDisplayCubit: widget.mapDisplayCubit,
      areaSearchResolver: widget.areaSearchResolver,
      onStateChanged: () {
        if (mounted) setState(() {});
      },
    );

    _session.initialize(
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
    _session.handleMapTap(tappedLatLng);
  }

  void _handleAddPointAtCenter() {
    final center = _mapLayerKey.currentState?.currentCenter ??
        _mapDisplayCubit.state.center;
    if (center == null) return;
    HapticFeedback.lightImpact();

    _session.handleAddPointAtCenter(center);
  }

  @override
  void dispose() {
    _session.dispose();
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
              RouteDrawingWorkspaceOverlay(
                topPadding: topPadding,
                drawingState: state,
                destinationController: _destController,
                drawingBloc: _drawingBloc,
                mapDisplayCubit: _mapDisplayCubit,
                currentCenter: () => _mapLayerKey.currentState?.currentCenter,
                onOpenSearch: () =>
                    _destController.handleSearch(context, mounted),
                onExit: () => Navigator.of(context).maybePop(),
                onSave: () =>
                    RouteDrawingActionCoordinator.showSaveRouteDialog(
                  context: context,
                  drawingBloc: _drawingBloc,
                ),
                onNavigate: () =>
                    RouteDrawingActionCoordinator.startNavigationFromDrawnRoute(
                  context: context,
                  state: state,
                ),
                onShowSavedRoutes: () =>
                    RouteDrawingActionCoordinator.showSavedRoutesSheet(
                  context: context,
                  drawingBloc: _drawingBloc,
                  savedRoutesCubit: _savedRoutesCubit,
                ),
                onAddPointAtCenter: _handleAddPointAtCenter,
                onControllerChanged: () => setState(() {}),
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

}
