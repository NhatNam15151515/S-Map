import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/main/home/widgets/map/home_interactive_map_layer.dart';

/// Giữ state và điều phối thao tác của chế độ vẽ tuyến trên Home.
class HomeRouteDrawingController {
  HomeRouteDrawingController({
    required RouteDrawingBloc drawingBloc,
    required MapDisplayCubit displayCubit,
    required RoutePreviewCubit routePreviewCubit,
    required GlobalKey<HomeInteractiveMapLayerState> mapLayerKey,
    required VoidCallback onStateChanged,
    required ValueChanged<PoiModel?> onSelectedPoiChanged,
  })  : _drawingBloc = drawingBloc,
        _displayCubit = displayCubit,
        _routePreviewCubit = routePreviewCubit,
        _mapLayerKey = mapLayerKey,
        _onStateChanged = onStateChanged,
        _onSelectedPoiChanged = onSelectedPoiChanged;

  final RouteDrawingBloc _drawingBloc;
  final MapDisplayCubit _displayCubit;
  final RoutePreviewCubit _routePreviewCubit;
  final GlobalKey<HomeInteractiveMapLayerState> _mapLayerKey;
  final VoidCallback _onStateChanged;
  final ValueChanged<PoiModel?> _onSelectedPoiChanged;

  bool isActive = false;
  bool isCrosshairActive = true;
  bool isToolsActive = false;
  List<PoiModel>? searchResults;
  String? searchQuery;
  bool _disposed = false;

  void dispose() => _disposed = true;

  void showSearchResults(List<PoiModel> pois, String? query) {
    _mapLayerKey.currentState?.clearSelectedPoiMarker(restoreSearchResults: false);
    _mapLayerKey.currentState?.showSearchResults(pois, fitBounds: true);
    _displayCubit.clearSelectedPoi();
    searchResults = pois;
    searchQuery = query;
    _onSelectedPoiChanged(null);
    _onStateChanged();
  }

  void closeSearchResults() {
    _mapLayerKey.currentState?.clearSearchResults();
    _mapLayerKey.currentState?.clearSelectedPoiMarker(restoreSearchResults: false);
    _displayCubit.clearSelectedPoi();
    searchResults = null;
    searchQuery = null;
    _onSelectedPoiChanged(null);
    _onStateChanged();
  }

  void enter(RouteDrawingPayload payload) {
    _mapLayerKey.currentState?.clearAll();
    _mapLayerKey.currentState?.clearDrawingRoute();
    _displayCubit.clearSelectedPoi();
    _routePreviewCubit.clearRoute();
    isActive = true;
    searchResults = null;
    searchQuery = null;
    isToolsActive = false;
    _onSelectedPoiChanged(null);
    _onStateChanged();
    _drawingBloc.add(const RouteDrawingReset());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed && isActive) _applyPayload(payload);
    });
  }

  void _applyPayload(RouteDrawingPayload payload) {
    if (payload.initialRoute != null) {
      _drawingBloc.add(RouteDrawingLoadRoute(payload.initialRoute!));
      return;
    }
    final origin = payload.initialOrigin;
    final destination = payload.initialDestination ??
        (payload.destinationPoi == null
            ? null
            : LatLng(payload.destinationPoi!.lat, payload.destinationPoi!.lon));
    final poiName = payload.destinationPoi == null
        ? ''
        : _poiDisplayName(payload.destinationPoi!);
    final name = poiName.trim().isNotEmpty ? poiName : payload.destinationName;

    if (origin != null && destination != null) {
      _drawingBloc.add(RouteDrawingEndpointsSelected(
        origin: RoutePoint(lat: origin.latitude, lon: origin.longitude),
        destination: RoutePoint(
          lat: destination.latitude,
          lon: destination.longitude,
        ),
        destinationName: name,
      ));
    } else if (origin != null) {
      _drawingBloc.add(RouteDrawingPointTapped(
        lat: origin.latitude,
        lon: origin.longitude,
      ));
    } else if (destination != null) {
      _drawingBloc.add(RouteDrawingPointTapped(
        lat: destination.latitude,
        lon: destination.longitude,
        displayName: name,
      ));
    }
    for (final waypoint in payload.additionalWaypoints ?? const <LatLng>[]) {
      _drawingBloc.add(RouteDrawingPointTapped(
        lat: waypoint.latitude,
        lon: waypoint.longitude,
      ));
    }
  }

  void exit() {
    _drawingBloc.add(const RouteDrawingReset());
    _mapLayerKey.currentState?.clearDrawingRoute();
    _mapLayerKey.currentState?.clearSearchResults();
    _displayCubit.clearSelectedPoi();
    _routePreviewCubit.clearRoute();
    isActive = false;
    searchResults = null;
    searchQuery = null;
    _onSelectedPoiChanged(null);
    _onStateChanged();
  }

  Future<void> addDestination(PoiModel poi) async {
    await _addDestinationPoint(
      LatLng(poi.lat, poi.lon),
      displayName: _poiDisplayName(poi),
    );
  }

  Future<void> addDestinationLocation(LatLng location) =>
      _addDestinationPoint(location);

  Future<void> _addDestinationPoint(
    LatLng point, {
    String displayName = '',
  }) async {
    final wasActive = isActive;
    isActive = true;
    if (!wasActive) _onStateChanged();
    final routeState = _routePreviewCubit.state;
    if (_drawingBloc.state.points.isEmpty && routeState.destination != null) {
      final position = _displayCubit.state.hasRealLocation
          ? _displayCubit.state.currentPosition
          : _displayCubit.state.center;
      final origin = routeState.origin ??
          (position == null
              ? RoutePoint(lat: point.latitude, lon: point.longitude)
              : RoutePoint(lat: position.latitude, lon: position.longitude));
      _drawingBloc.add(RouteDrawingEndpointsSelected(
        origin: origin,
        destination: routeState.destination!,
        destinationName: routeState.destinationName,
      ));
      await _drawingBloc.stream.firstWhere(
        (state) => state.points.length >= 2 && !state.isLoading,
      );
      if (_disposed) return;
      _routePreviewCubit.clearRoute();
      isToolsActive = false;
    } else if (_drawingBloc.state.points.isEmpty) {
      final state = _displayCubit.state;
      final origin = state.hasRealLocation ? state.currentPosition : state.center;
      if (origin != null) {
        _drawingBloc.add(RouteDrawingEndpointsSelected(
          origin: RoutePoint(lat: origin.latitude, lon: origin.longitude),
          destination: RoutePoint(lat: point.latitude, lon: point.longitude),
          destinationName: displayName,
        ));
        isActive = true;
        _finishAddingDestination(point);
        return;
      }
    }
    isActive = true;
    _drawingBloc.add(RouteDrawingPointTapped(
      lat: point.latitude,
      lon: point.longitude,
      displayName: displayName,
    ));
    _finishAddingDestination(point);
  }

  void _finishAddingDestination(LatLng point) {
    _mapLayerKey.currentState?.clearSelectedPoiMarker(restoreSearchResults: true);
    _displayCubit.clearSelectedPoi();
    _displayCubit.zoomToLevel(16.0, center: point);
    _onSelectedPoiChanged(null);
    _onStateChanged();
  }

  void handleMapTap(LatLng position) => _drawingBloc.add(
        RouteDrawingPointTapped(lat: position.latitude, lon: position.longitude),
      );

  void addPointAtCenter() {
    final center = _mapLayerKey.currentState?.currentCenter ??
        _displayCubit.state.center;
    if (center != null) handleMapTap(center);
  }

  void toggleCrosshair() {
    isCrosshairActive = !isCrosshairActive;
    _onStateChanged();
  }

  void toggleTools() {
    isToolsActive = !isToolsActive;
    _onStateChanged();
  }

  String _poiDisplayName(PoiModel poi) {
    final name = poi.name.trim();
    if (name.isNotEmpty) return name;
    final address = poi.address?.trim() ?? '';
    if (address.isNotEmpty) return address;
    return [poi.housenumber, poi.street, poi.city]
        .where((part) => part != null && part.trim().isNotEmpty)
        .map((part) => part!.trim())
        .join(', ');
  }
}
