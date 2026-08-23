import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/repos/repos.dart';
import 'package:s_map/routers/app_routes.dart';
import 'widgets/widgets.dart';

class RouteDrawingScreen extends StatefulWidget {
  static const String path = AppRoutes.routeDrawing;

  final RouteDrawingBloc? drawingBloc;
  final SavedRoutesCubit? savedRoutesCubit;
  final MapDisplayCubit? mapDisplayCubit;

  /// Optional builder to replace the map layer widget (for testing).
  final Widget Function()? mapLayerBuilder;

  const RouteDrawingScreen({
    super.key,
    this.drawingBloc,
    this.savedRoutesCubit,
    this.mapDisplayCubit,
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
    final defaultName =
        'Lộ trình ${DateFormat('dd/MM/yyyy HH:mm').format(now)}';

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
    final instructions = <RouteInstruction>[
      RouteInstruction(
        text: 'Đi theo lộ trình tùy biến',
        streetName: 'Lộ trình tùy biến',
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

    context.push(
      AppRoutes.navigation,
      extra: {
        'initialRoute': customRoute,
        'origin': state.fullPolyline.first,
        'destination': state.fullPolyline.last,
        'destinationName': 'Lộ trình tùy biến',
      },
    );
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
        backgroundColor: AppColors.white,
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

                // 3. Floating Toolbar (Undo, Redo, Clear, Fit Bounds)
                RouteDrawingFloatingToolbar(
                  canUndo: state.canUndo,
                  canRedo: state.canRedo,
                  canClear: state.points.isNotEmpty,
                  hasPoints: state.points.isNotEmpty,
                  onUndo: () => _drawingBloc.add(const RouteDrawingUndoLastPoint()),
                  onRedo: () => _drawingBloc.add(const RouteDrawingRedoPoint()),
                  onClear: () => _drawingBloc.add(const RouteDrawingClearRoute()),
                  onFitBounds: () => _mapLayerKey.currentState?.fitRouteBounds(),
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
