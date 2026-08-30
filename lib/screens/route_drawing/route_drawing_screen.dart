import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
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

  late final RouteDrawingBloc _drawingBloc;
  late final SavedRoutesCubit _savedRoutesCubit;
  late final MapDisplayCubit _mapDisplayCubit;

  bool _isMyLocationOriginActive = false;
  bool _isMarkerDestinationActive = false;
  LatLng? _markerDestination;

  @override
  void initState() {
    super.initState();
    _mapDisplayCubit = widget.mapDisplayCubit ?? MapDisplayCubit();
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
    final effectiveOrigin = widget.initialOrigin ?? payload?.initialOrigin;
    _markerDestination = widget.initialDestination ??
        payload?.initialDestination ??
        (payload?.destinationPoi != null
            ? LatLng(payload!.destinationPoi!.lat, payload.destinationPoi!.lon)
            : null);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (effectiveOrigin != null) {
        _drawingBloc.add(
          RouteDrawingPointTapped(
            lat: effectiveOrigin.latitude,
            lon: effectiveOrigin.longitude,
          ),
        );
        setState(() => _isMyLocationOriginActive = true);
      }
      if (_markerDestination != null) {
        _drawingBloc.add(
          RouteDrawingPointTapped(
            lat: _markerDestination!.latitude,
            lon: _markerDestination!.longitude,
          ),
        );
        setState(() => _isMarkerDestinationActive = true);
      }
    });
  }

  void _handleToggleMyLocationOrigin() {
    final currentPos = _mapDisplayCubit.state.currentPosition;
    if (currentPos == null) {
      _mapDisplayCubit.locateMe();
      return;
    }

    setState(() {
      _isMyLocationOriginActive = !_isMyLocationOriginActive;
    });

    if (_isMyLocationOriginActive) {
      if (_drawingBloc.state.points.isEmpty) {
        _drawingBloc.add(
          RouteDrawingPointTapped(
            lat: currentPos.latitude,
            lon: currentPos.longitude,
          ),
        );
      }
    }
  }

  void _handleToggleMarkerDestination() {
    if (_markerDestination == null) return;

    setState(() {
      _isMarkerDestinationActive = !_isMarkerDestinationActive;
    });

    if (_isMarkerDestinationActive) {
      _drawingBloc.add(
        RouteDrawingPointTapped(
          lat: _markerDestination!.latitude,
          lon: _markerDestination!.longitude,
        ),
      );
    } else {
      if (_drawingBloc.state.canUndo) {
        _drawingBloc.add(const RouteDrawingUndoLastPoint());
      }
    }
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
      child: Scaffold(
        body: BlocBuilder<RouteDrawingBloc, RouteDrawingState>(
          builder: (context, state) {
            return Stack(
              children: [
                // 1. Map Layer
                if (widget.mapLayerBuilder != null)
                  widget.mapLayerBuilder!()
                else
                  RouteDrawingMapLayer(key: _mapLayerKey),

                // 2. Floating Top Bar
                RouteDrawingTopBar(
                  topPadding: topPadding,
                  onSavedRoutesPressed: () => _handleOpenSavedRoutes(context),
                ),

                // 3. Floating Toolbar (Undo, Redo, Clear, Fit Bounds, Origin/Dest Toggles)
                RouteDrawingFloatingToolbar(
                  canUndo: state.canUndo,
                  canRedo: state.canRedo,
                  canClear: state.points.isNotEmpty,
                  hasPoints: state.points.isNotEmpty,
                  isMyLocationOrigin: _isMyLocationOriginActive,
                  isMarkerDestination: _isMarkerDestinationActive,
                  hasMarkerDestination: _markerDestination != null,
                  onUndo: () =>
                      _drawingBloc.add(const RouteDrawingUndoLastPoint()),
                  onRedo: () => _drawingBloc.add(const RouteDrawingRedoPoint()),
                  onClear: () {
                    setState(() {
                      _isMyLocationOriginActive = false;
                      _isMarkerDestinationActive = false;
                    });
                    _drawingBloc.add(const RouteDrawingClearRoute());
                  },
                  onFitBounds: () =>
                      _mapLayerKey.currentState?.fitRouteBounds(),
                  onToggleMyLocationOrigin: _handleToggleMyLocationOrigin,
                  onToggleMarkerDestination: _markerDestination != null
                      ? _handleToggleMarkerDestination
                      : null,
                ),

                // 4. Bottom Summary & Action Card
                RouteDrawingBottomCard(
                  pointCount: state.pointCount,
                  distanceMeters: state.totalDistance,
                  durationMs: state.totalTime,
                  isLoading: state.isLoading,
                  onSavePressed: () => _handleSaveRoute(context, state),
                  onNavigatePressed: () => _handleNavigate(context, state),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
