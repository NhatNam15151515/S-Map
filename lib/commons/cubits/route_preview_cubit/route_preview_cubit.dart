import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/fallbacks/fallbacks.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'route_preview_state.dart';

class RoutePreviewCubit extends Cubit<RoutePreviewState> {
  final IRoutingRepository _routingRepository;
  final ILocationService _locationService;
  int _currentGeneration = 0;
  int _previewRequestGeneration = 0;

  /// Optional global default service resolver set by the composition root
  static ILocationService? defaultLocationService;

  RoutePreviewCubit({
    required IRoutingRepository routingRepository,
    ILocationService? locationService,
  })  : _routingRepository = routingRepository,
        _locationService = locationService ??
            defaultLocationService ??
            const NoOpLocationService(),
        super(const RoutePreviewState());

  @override
  void emit(RoutePreviewState state) {
    if (isClosed) return;
    super.emit(state);
  }

  /// Lấy vị trí GPS hiện tại hoặc fallback về vị trí mặc định an toàn
  Future<LatLng> _getUserPosition() async {
    try {
      final lastKnown = await _locationService.getLastKnownPosition();
      if (lastKnown != null) {
        DLog.info('📍 [GPS] Using last known location: (${lastKnown.latitude}, ${lastKnown.longitude})');
        return LatLng(lastKnown.latitude, lastKnown.longitude);
      }
      final current = await _locationService.getCurrentPosition();
      DLog.info('📍 [GPS] Acquired current location: (${current.latitude}, ${current.longitude})');
      return LatLng(current.latitude, current.longitude);
    } catch (e, stack) {
      DLog.warning('⚠️ [GPS] Failed to resolve user location, falling back to default location: $e', stack);
      return MapConstants.defaultLocation;
    }
  }

  /// Kích hoạt tính toán lộ trình xe máy đến một POI cụ thể từ vị trí hiện tại
  Future<void> previewRouteToPoi(PoiModel poi) async {
    final previewGeneration = ++_previewRequestGeneration;
    DLog.info('🔍 [RoutePreviewCubit] previewRouteToPoi: "${poi.name}" (${poi.lat}, ${poi.lon})');
    final userPos = await _getUserPosition();
    if (previewGeneration != _previewRequestGeneration || isClosed) return;
    await getRoute(
      origin: RoutePoint(lat: userPos.latitude, lon: userPos.longitude),
      destination: RoutePoint(lat: poi.lat, lon: poi.lon),
      originName: null,
      destinationName: poi.name,
    );
  }

  /// Kích hoạt tính toán lộ trình xe máy đến tọa độ bất kỳ (ví dụ khi Long Press trên Map)
  Future<void> previewRouteToCoordinate(LatLng target, {String? targetName}) async {
    final previewGeneration = ++_previewRequestGeneration;
    DLog.info('🔍 [RoutePreviewCubit] previewRouteToCoordinate: (${target.latitude}, ${target.longitude}) - name: "$targetName"');
    final userPos = await _getUserPosition();
    if (previewGeneration != _previewRequestGeneration || isClosed) return;
    await getRoute(
      origin: RoutePoint(lat: userPos.latitude, lon: userPos.longitude),
      destination: RoutePoint(lat: target.latitude, lon: target.longitude),
      originName: null,
      destinationName: targetName,
    );
  }

  /// Kích hoạt tính toán lộ trình giữa 2 điểm bất kỳ (Origin và Destination)
  Future<void> previewRouteBetweenPoints({
    required RoutePoint origin,
    required RoutePoint destination,
    String? originName,
    String? destinationName,
    String? profile,
  }) async {
    await getRoute(
      origin: origin,
      destination: destination,
      originName: originName,
      destinationName: destinationName,
      profile: profile,
    );
  }

  /// Tính toán lộ trình từ điểm xuất phát đến đích với phương tiện chỉ định
  Future<void> getRoute({
    required RoutePoint origin,
    required RoutePoint destination,
    String? originName,
    String? destinationName,
    String? profile,
  }) async {
    final selectedProfile = profile ?? state.profile;
    final generation = ++_currentGeneration;

    DLog.info('🏍️ [RoutePreviewCubit] Calculating route [Gen #$generation]: from "${originName ?? 'my_location'}" (${origin.lat.toStringAsFixed(5)}, ${origin.lon.toStringAsFixed(5)}) to "${destinationName ?? 'destination'}" (${destination.lat.toStringAsFixed(5)}, ${destination.lon.toStringAsFixed(5)}) | Profile: $selectedProfile');

    emit(state.copyWith(
      status: RoutePreviewStatus.loading,
      origin: origin,
      destination: destination,
      originName: originName,
      destinationName: destinationName,
      clearOriginName: originName == null,
      clearDestinationName: destinationName == null,
      profile: selectedProfile,
      requestGeneration: generation,
      clearError: true,
    ));

    try {
      final routes = await _routingRepository.calculateAlternativeRoutes(
        fromLat: origin.lat,
        fromLon: origin.lon,
        toLat: destination.lat,
        toLon: destination.lon,
        vehicleProfile: selectedProfile,
      );

      if (generation != _currentGeneration) {
        DLog.info('⏭️ [RoutePreviewCubit] Stale route response ignored (Current gen #$_currentGeneration vs #$generation)');
        return;
      }

      final result = routes.isNotEmpty ? routes.first : null;

      if (result != null && result.isSuccess) {
        DLog.info('✅ [RoutePreviewCubit] Route calculated successfully: distance = ${(result.distance / 1000).toStringAsFixed(2)}km, time = ${(result.time / 60000).round()} mins, waypoints = ${result.points.length}, alternatives = ${routes.length}');
        emit(state.copyWith(
          status: RoutePreviewStatus.success,
          routeResult: result,
          alternativeRoutes: routes,
          selectedRouteIndex: 0,
          origin: origin,
          destination: destination,
          originName: originName,
          destinationName: destinationName,
          clearOriginName: originName == null,
          clearDestinationName: destinationName == null,
          profile: selectedProfile,
          requestGeneration: generation,
          clearError: true,
        ));
      } else {
        DLog.error('❌ [RoutePreviewCubit] Route calculation failed: ${result?.errorMessage}');
        emit(state.copyWith(
          status: RoutePreviewStatus.error,
          errorMessageKey: result?.errorMessage ?? RoutingConstants.errNoRouteFound,
          requestGeneration: generation,
          clearRoute: true,
        ));
      }
    } catch (e, stack) {
      if (generation != _currentGeneration) return;
      DLog.error('❌ [RoutePreviewCubit] Exception in getRoute: $e', e, stack);
      emit(state.copyWith(
        status: RoutePreviewStatus.error,
        errorMessageKey: LocaleKeys.routing_error_generic,
        requestGeneration: generation,
        clearRoute: true,
      ));
    }
  }

  /// Hoán đổi điểm xuất phát và điểm đến (Swap A <-> B)
  Future<void> swapEndpoints() async {
    if (state.origin == null || state.destination == null) return;
    DLog.info('🔄 [RoutePreviewCubit] Swapping origin and destination');
    final oldOrigin = state.origin!;
    final oldDest = state.destination!;
    final oldOriginName = state.originName;
    final oldDestName = state.destinationName;

    await getRoute(
      origin: oldDest,
      destination: oldOrigin,
      originName: oldDestName,
      destinationName: oldOriginName,
      profile: state.profile,
    );
  }

  /// Thay đổi phương tiện di chuyển và tự động tính lại lộ trình
  Future<void> changeProfile(String newProfile) async {
    DLog.info('🔄 [RoutePreviewCubit] Changing profile from "${state.profile}" to "$newProfile"');
    if (state.origin == null || state.destination == null) {
      emit(state.copyWith(profile: newProfile));
      return;
    }

    if (state.profile == newProfile && state.hasRoute) {
      return;
    }

    await getRoute(
      origin: state.origin!,
      destination: state.destination!,
      originName: state.originName,
      destinationName: state.destinationName,
      profile: newProfile,
    );
  }

  /// Lựa chọn lộ trình thay thế trong danh sách đã tính toán
  void selectAlternativeRoute(int index) {
    if (state.alternativeRoutes.isEmpty ||
        index < 0 ||
        index >= state.alternativeRoutes.length) {
      return;
    }
    if (state.selectedRouteIndex == index) return;

    final selected = state.alternativeRoutes[index];
    DLog.info(
        '🔀 [RoutePreviewCubit] Selecting alternative route #$index: distance = ${(selected.distance / 1000).toStringAsFixed(2)}km, time = ${(selected.time / 60000).round()} mins');

    emit(state.copyWith(
      selectedRouteIndex: index,
      routeResult: selected,
    ));
  }

  /// Nạp danh sách các phương án lộ trình thay thế
  void setAlternativeRoutes(List<RouteResult> routes, {int initialIndex = 0}) {
    if (routes.isEmpty) return;
    final validIndex = initialIndex.clamp(0, routes.length - 1);
    emit(state.copyWith(
      alternativeRoutes: routes,
      selectedRouteIndex: validIndex,
      routeResult: routes[validIndex],
    ));
  }

  /// Dọn sạch toàn bộ lộ trình và đưa trạng thái về ban đầu
  void clearRoute() {
    DLog.info('🧹 [RoutePreviewCubit] Clearing route preview state');
    _currentGeneration++;
    _previewRequestGeneration++;
    emit(const RoutePreviewState());
  }
}
