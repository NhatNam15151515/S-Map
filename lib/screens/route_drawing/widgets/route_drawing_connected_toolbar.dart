import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'route_drawing_destination_controller.dart';
import 'route_drawing_floating_toolbar.dart';
import 'route_drawing_map_layer.dart';

/// Widget kết nối state → [RouteDrawingFloatingToolbar].
///
/// Trách nhiệm duy nhất:
/// - Map bloc state & cubit → callback wiring cho toolbar
/// - Giữ logic setState cho crosshair toggle, clear, reverse
class RouteDrawingConnectedToolbar extends StatelessWidget {
  final RouteDrawingState state;
  final RouteDrawingDestinationController destController;
  final MapDisplayCubit mapDisplayCubit;
  final RouteDrawingBloc drawingBloc;
  final GlobalKey<RouteDrawingMapLayerState> mapLayerKey;
  final VoidCallback onSetState;

  const RouteDrawingConnectedToolbar({
    super.key,
    required this.state,
    required this.destController,
    required this.mapDisplayCubit,
    required this.drawingBloc,
    required this.mapLayerKey,
    required this.onSetState,
  });

  @override
  Widget build(BuildContext context) {
    return RouteDrawingFloatingToolbar(
      canUndo: state.canUndo,
      canRedo: state.canRedo,
      canClear: state.points.isNotEmpty,
      hasPoints: state.points.isNotEmpty,
      onLocateMe: mapDisplayCubit.locateMe,
      onUndo: () => drawingBloc.add(const RouteDrawingUndoLastPoint()),
      onRedo: () => drawingBloc.add(const RouteDrawingRedoPoint()),
      onReverseRoute: () {
        HapticFeedback.mediumImpact();
        drawingBloc.add(const RouteDrawingReverseRoute());
      },
      canReverse: state.points.length >= 2,
      isCrosshairActive: destController.isCrosshairActive,
      onToggleCrosshair: () {
        HapticFeedback.selectionClick();
        destController.isCrosshairActive = !destController.isCrosshairActive;
        onSetState();
      },
      onClear: () {
        destController.markerDestination = null;
        destController.isDestinationPickerActive = false;
        onSetState();
        drawingBloc.add(const RouteDrawingClearRoute());
      },
    );
  }
}
