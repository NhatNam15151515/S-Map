import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/services/services.dart';
import 'route_preview_state.dart';

class RoutePreviewCubit extends Cubit<RoutePreviewState> {
  final IRoutingRepository _routingRepository;
  final ILocationService _locationService;
  int _currentGeneration = 0;

  RoutePreviewCubit({
    required IRoutingRepository routingRepository,
    ILocationService? locationService,
  })  : _routingRepository = routingRepository,
        _locationService = locationService ?? LocationService.instance,
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
    DLog.info('🔍 [RoutePreviewCubit] previewRouteToPoi: "${poi.name}" (${poi.lat}, ${poi.lon})');
    final userPos = await _getUserPosition();
    await getRoute(
      origin: RoutePoint(lat: userPos.latitude, lon: userPos.longitude),
      destination: RoutePoint(lat: poi.lat, lon: poi.lon),
      destinationName: poi.name,
    );
  }

  /// Kích hoạt tính toán lộ trình xe máy đến tọa độ bất kỳ (ví dụ khi Long Press trên Map)
  Future<void> previewRouteToCoordinate(LatLng target, {String? targetName}) async {
    DLog.info('🔍 [RoutePreviewCubit] previewRouteToCoordinate: (${target.latitude}, ${target.longitude}) - name: "$targetName"');
    final userPos = await _getUserPosition();
    await getRoute(
      origin: RoutePoint(lat: userPos.latitude, lon: userPos.longitude),
      destination: RoutePoint(lat: target.latitude, lon: target.longitude),
      destinationName: targetName,
    );
  }

  /// Tính toán lộ trình từ điểm xuất phát đến đích với phương tiện chỉ định
  Future<void> getRoute({
    required RoutePoint origin,
    required RoutePoint destination,
    String? destinationName,
    String? profile,
  }) async {
    final selectedProfile = profile ?? state.profile;
    final generation = ++_currentGeneration;

    DLog.info('🏍️ [RoutePreviewCubit] Calculating motorcycle route [Gen #$generation]: from (${origin.lat.toStringAsFixed(5)}, ${origin.lon.toStringAsFixed(5)}) to (${destination.lat.toStringAsFixed(5)}, ${destination.lon.toStringAsFixed(5)}) | Profile: $selectedProfile | Dest: "$destinationName"');

    emit(state.copyWith(
      status: RoutePreviewStatus.loading,
      origin: origin,
      destination: destination,
      destinationName: destinationName,
      clearDestinationName: destinationName == null,
      profile: selectedProfile,
      requestGeneration: generation,
      clearError: true,
    ));

    try {
      final result = await _routingRepository.calculateRoute(
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

      if (result.isSuccess) {
        DLog.info('✅ [RoutePreviewCubit] Route calculated successfully: distance = ${(result.distance / 1000).toStringAsFixed(2)}km, time = ${(result.time / 60000).round()} mins, waypoints = ${result.points.length}');
        emit(state.copyWith(
          status: RoutePreviewStatus.success,
          routeResult: result,
          origin: origin,
          destination: destination,
          destinationName: destinationName,
          clearDestinationName: destinationName == null,
          profile: selectedProfile,
          requestGeneration: generation,
          clearError: true,
        ));
      } else {
        DLog.error('❌ [RoutePreviewCubit] Route calculation failed: ${result.errorMessage}');
        emit(state.copyWith(
          status: RoutePreviewStatus.error,
          errorMessageKey: result.errorMessage ?? RoutingConstants.errNoRouteFound,
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
      destinationName: state.destinationName,
      profile: newProfile,
    );
  }

  /// Dọn sạch toàn bộ lộ trình và đưa trạng thái về ban đầu
  void clearRoute() {
    DLog.info('🧹 [RoutePreviewCubit] Clearing route preview state');
    _currentGeneration++;
    emit(const RoutePreviewState());
  }
}
