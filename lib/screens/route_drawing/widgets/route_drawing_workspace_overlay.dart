import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/models/models.dart';
import 'route_drawing_connected_toolbar.dart';
import 'route_drawing_crosshair_overlay.dart';
import 'route_drawing_bottom_card.dart';
import 'route_drawing_destination_picker_overlay.dart';
import 'route_drawing_destination_controller.dart';
import 'route_drawing_waypoint_panel.dart';

/// Bộ UI route drawing dùng chung cho Home và entry route drawing cũ.
class RouteDrawingWorkspaceOverlay extends StatelessWidget {
  final double topPadding;
  final RouteDrawingState drawingState;
  final RouteDrawingDestinationController destinationController;
  final RouteDrawingBloc drawingBloc;
  final MapDisplayCubit mapDisplayCubit;
  final List<PoiModel>? searchResults;
  final String? searchQuery;
  final PoiModel? selectedPoi;
  final LatLng? Function()? currentCenter;
  final VoidCallback onOpenSearch;
  final VoidCallback onExit;
  final VoidCallback onSave;
  final VoidCallback onNavigate;
  final VoidCallback onShowSavedRoutes;
  final ValueChanged<PoiModel>? onPoiTap;
  final ValueChanged<PoiModel>? onAddDestination;
  final VoidCallback? onCloseSearch;
  final VoidCallback? onClosePoi;
  final VoidCallback onAddPointAtCenter;
  final VoidCallback onControllerChanged;

  const RouteDrawingWorkspaceOverlay({
    super.key,
    required this.topPadding,
    required this.drawingState,
    required this.destinationController,
    required this.drawingBloc,
    required this.mapDisplayCubit,
    this.searchResults,
    this.searchQuery,
    this.selectedPoi,
    this.currentCenter,
    required this.onOpenSearch,
    required this.onExit,
    required this.onSave,
    required this.onNavigate,
    required this.onShowSavedRoutes,
    this.onPoiTap,
    this.onAddDestination,
    this.onCloseSearch,
    this.onClosePoi,
    required this.onAddPointAtCenter,
    required this.onControllerChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasSearchResults = searchResults != null;

    return Stack(
      children: [
        RouteDrawingWaypointPanel(
          topPadding: topPadding,
          points: drawingState.points,
          segments: drawingState.segments,
          onSavedRoutesPressed: onShowSavedRoutes,
          onSearchDestinationPressed: onOpenSearch,
          onReorder: (oldIndex, newIndex) => drawingBloc.add(
            RouteDrawingReorderPoints(oldIndex, newIndex),
          ),
          onRemovePoint: (index) => drawingBloc.add(
            RouteDrawingRemovePoint(index),
          ),
          onToggleSegmentStraightLine: (segmentIndex) => drawingBloc.add(
            RouteDrawingToggleSegmentStraightLine(segmentIndex),
          ),
        ),
        if (destinationController.isDestinationPickerActive)
          RouteDrawingDestinationPickerOverlay(
            onConfirm: () {
              final center = currentCenter?.call() ??
                  mapDisplayCubit.state.center ??
                  MapConstants.defaultLocation;
              destinationController.handleConfirmPicker(center);
            },
            onCancel: destinationController.handleCancelPicker,
            bottomOffset: MediaQuery.paddingOf(context).bottom +
                (drawingState.points.length >= 2 ? 200 : 140),
          )
        else if (destinationController.isCrosshairActive)
          RouteDrawingCrosshairOverlay(
            isLoading: drawingState.isLoading,
            hasPoints: drawingState.points.isNotEmpty,
            onAddPoint: onAddPointAtCenter,
            bottomOffset: MediaQuery.paddingOf(context).bottom +
                (drawingState.points.length >= 2 ? 190 : 130),
          ),
        if (!hasSearchResults && selectedPoi == null)
          RouteDrawingBottomCard(
            pointCount: drawingState.pointCount,
            distanceMeters: drawingState.totalDistance,
            durationMs: drawingState.totalTime,
            isLoading: drawingState.isLoading,
            isStraightLineMode: drawingState.isStraightLineMode,
            onClose: onExit,
            onSavePressed: onSave,
            onNavigatePressed: onNavigate,
          ),
        if (hasSearchResults && selectedPoi == null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.72,
              child: SafeArea(
                top: false,
                child: SearchResultsBottomSheet(
                  key: const ValueKey('route_drawing_search_results'),
                  pois: searchResults!,
                  query: searchQuery,
                  hasExistingDestinations: true,
                  onPoiTap: onPoiTap,
                  onAddDestination: onAddDestination,
                  onClose: onCloseSearch,
                ),
              ),
            ),
          ),
        if (hasSearchResults && selectedPoi != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: PoiQuickCard(
                poi: selectedPoi!,
                onClose: onClosePoi ?? () {},
                onAddDestination: onAddDestination == null
                    ? null
                    : () => onAddDestination!(selectedPoi!),
              ),
            ),
          ),
        RouteDrawingConnectedToolbar(
          state: drawingState,
          destController: destinationController,
          mapDisplayCubit: mapDisplayCubit,
          drawingBloc: drawingBloc,
          onSetState: onControllerChanged,
        ),
      ],
    );
  }
}
