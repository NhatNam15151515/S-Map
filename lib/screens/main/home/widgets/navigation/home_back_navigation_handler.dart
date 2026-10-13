import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/main/home/widgets/map/home_interactive_map_layer.dart';
import 'package:s_map/screens/main/home/widgets/drawing/home_route_drawing_controller.dart';
import 'package:s_map/screens/main/home/widgets/home/home_search_coordinator.dart';

/// Applies the Home-specific back stack before delegating to the OS.
class HomeBackNavigationHandler {
  HomeBackNavigationHandler({
    required GlobalKey<HomeInteractiveMapLayerState> mapLayerKey,
    required RoutePreviewCubit routePreviewCubit,
    required HomeSearchCoordinator searchCoordinator,
    required HomeRouteDrawingController drawingController,
    required String exitHint,
    required VoidCallback onStateChanged,
  })  : _mapLayerKey = mapLayerKey,
        _routePreviewCubit = routePreviewCubit,
        _searchCoordinator = searchCoordinator,
        _drawingController = drawingController,
        _exitHint = exitHint,
        _onStateChanged = onStateChanged;

  final GlobalKey<HomeInteractiveMapLayerState> _mapLayerKey;
  final RoutePreviewCubit _routePreviewCubit;
  final HomeSearchCoordinator _searchCoordinator;
  final HomeRouteDrawingController _drawingController;
  final String _exitHint;
  final VoidCallback _onStateChanged;
  DateTime? _lastBackPressedAt;
  bool _isExitDialogOpen = false;

  Future<void> confirmExitDrawing(BuildContext context) async {
    if (_isExitDialogOpen) return;
    _isExitDialogOpen = true;
    try {
      final shouldExit = await AppConfirmDialog.show(
        context,
        title: tr(LocaleKeys.route_drawing_ui_exit_confirm_title),
        message: tr(LocaleKeys.route_drawing_ui_exit_confirm_desc),
        confirmText: tr(LocaleKeys.route_drawing_ui_exit_confirm_action),
        isDestructive: true,
        icon: Icons.exit_to_app_rounded,
        confirmKey: const Key('route_drawing_exit_confirm_button'),
        cancelKey: const Key('route_drawing_exit_cancel_button'),
      );
      if (shouldExit == true && context.mounted) _drawingController.exit();
    } finally {
      _isExitDialogOpen = false;
    }
  }

  Future<void> handle(
    BuildContext context, {
    required PoiModel? selectedPoi,
    required VoidCallback onCloseExplorePoi,
    required VoidCallback onCloseDrawingPoi,
  }) async {
    if (selectedPoi != null) {
      (_drawingController.isActive ? onCloseDrawingPoi : onCloseExplorePoi)();
      return;
    }
    if (_drawingController.searchResults != null) {
      _drawingController.closeSearchResults();
      return;
    }
    if (_drawingController.isActive) {
      await confirmExitDrawing(context);
      return;
    }
    if (_searchCoordinator.searchResults.isNotEmpty ||
        _searchCoordinator.activeSearchText != null ||
        _searchCoordinator.showSearchThisArea) {
      _searchCoordinator.handleCloseSearchResults();
      return;
    }
    final routeState = _routePreviewCubit.state;
    if (routeState.isLoading || routeState.isSuccess) {
      _routePreviewCubit.clearRoute();
      _mapLayerKey.currentState?.clearDrawingRoute();
      return;
    }

    final now = DateTime.now();
    final previousPress = _lastBackPressedAt;
    if (previousPress != null &&
        now.difference(previousPress) <= const Duration(seconds: 2)) {
      _lastBackPressedAt = null;
      await SystemNavigator.pop();
      return;
    }
    _lastBackPressedAt = now;
    _onStateChanged();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(_exitHint),
        duration: const Duration(seconds: 2),
      ));
  }
}
