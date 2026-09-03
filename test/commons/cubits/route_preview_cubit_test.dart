import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

class FakeRoutingRepository implements IRoutingRepository {
  Duration delay = Duration.zero;
  bool shouldThrow = false;
  RouteResult? customResult;
  Future<RouteResult> Function(
          double fromLat, double fromLon, double toLat, double toLon)?
      customRouteHandler;
  int callCount = 0;
  String? lastProfile;

  @override
  Future<RouteResult> calculateRoute({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    String? vehicleProfile,
  }) async {
    callCount++;
    lastProfile = vehicleProfile;
    if (customRouteHandler != null) {
      return customRouteHandler!(fromLat, fromLon, toLat, toLon);
    }
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    if (shouldThrow) {
      throw Exception('Network or platform error');
    }
    return customResult ??
        const RouteResult(
          isSuccess: true,
          distance: 3500.0,
          time: 420000,
          points: [
            [21.0285, 105.8542],
            [21.0350, 105.8450],
          ],
          instructions: [],
        );
  }

  List<RouteResult>? customAlternativeRoutes;

  @override
  Future<List<RouteResult>> calculateAlternativeRoutes({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    String? vehicleProfile,
  }) async {
    if (customAlternativeRoutes != null) {
      callCount++;
      return customAlternativeRoutes!;
    }
    final primary = await calculateRoute(
      fromLat: fromLat,
      fromLon: fromLon,
      toLat: toLat,
      toLon: toLon,
      vehicleProfile: vehicleProfile,
    );
    return [primary];
  }

  @override
  Future<SnappedRoadPoint> snapToRoad({
    required double lat,
    required double lon,
  }) async =>
      SnappedRoadPoint(
        isSnapped: true,
        originalLat: lat,
        originalLon: lon,
        snappedLat: lat,
        snappedLon: lon,
      );

  @override
  Future<bool> initializeEngine(String graphPath) async => true;

  @override
  Future<bool> isEngineReady() async => true;

  @override
  Future<bool> dispose() async => true;
}

class FakeLocationService implements ILocationService {
  Position mockPosition = Position(
    latitude: 21.0285,
    longitude: 105.8542,
    timestamp: DateTime.now(),
    accuracy: 10.0,
    altitude: 0.0,
    altitudeAccuracy: 0.0,
    heading: 0.0,
    headingAccuracy: 0.0,
    speed: 0.0,
    speedAccuracy: 0.0,
  );

  @override
  Position get position => mockPosition;

  @override
  (double, double) get latLng =>
      (mockPosition.latitude, mockPosition.longitude);

  @override
  Stream<Position> get positionStream => Stream.value(mockPosition);

  @override
  Future<Position> getCurrentPosition() async => mockPosition;

  @override
  Future<Position?> getLastKnownPosition() async => mockPosition;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.always;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.always;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Stream<Position> getPositionStream({
    LocationAccuracy accuracy = LocationAccuracy.bestForNavigation,
    int distanceFilter = 0,
    Duration? intervalDuration,
    bool enableBackground = false,
    String? notificationTitle,
    String? notificationText,
    bool enableWakeLock = true,
  }) =>
      Stream.value(mockPosition);

  @override
  Future<bool> isBatteryOptimizationIgnored() async => true;

  @override
  Future<bool> requestIgnoreBatteryOptimization() async => true;

  @override
  Future<bool> requestNotificationPermission() async => true;
}

class _ThrowingLocationService implements ILocationService {
  @override
  Position get position => throw UnimplementedError();
  @override
  (double, double) get latLng => throw UnimplementedError();
  @override
  Stream<Position> get positionStream => const Stream.empty();
  @override
  Future<Position> getCurrentPosition() async =>
      throw const PermissionDeniedException('Test: permission denied');
  @override
  Future<Position?> getLastKnownPosition() async =>
      throw const PermissionDeniedException('Test: permission denied');
  @override
  Future<bool> isLocationServiceEnabled() async => false;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.denied;
  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.denied;
  @override
  Future<bool> openLocationSettings() async => false;
  @override
  Future<bool> openAppSettings() async => false;
  @override
  Stream<Position> getPositionStream({
    LocationAccuracy accuracy = LocationAccuracy.bestForNavigation,
    int distanceFilter = 0,
    Duration? intervalDuration,
    bool enableBackground = false,
    String? notificationTitle,
    String? notificationText,
    bool enableWakeLock = true,
  }) =>
      const Stream.empty();
  @override
  Future<bool> isBatteryOptimizationIgnored() async => false;
  @override
  Future<bool> requestIgnoreBatteryOptimization() async => false;
  @override
  Future<bool> requestNotificationPermission() async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const origin = RoutePoint(
    lat: 21.0285,
    lon: 105.8542,
  );
  const destination = RoutePoint(
    lat: 21.0350,
    lon: 105.8450,
  );

  group('RoutePreviewCubit Tests', () {
    late FakeRoutingRepository fakeRepo;
    late FakeLocationService fakeLocationService;
    late RoutePreviewCubit cubit;

    setUp(() {
      fakeRepo = FakeRoutingRepository();
      fakeLocationService = FakeLocationService();
      cubit = RoutePreviewCubit(
        routingRepository: fakeRepo,
        locationService: fakeLocationService,
      );
    });

    tearDown(() {
      cubit.close();
    });

    test('Initial state is idle/initial with default moped_vn profile', () {
      expect(cubit.state.status, equals(RoutePreviewStatus.initial));
      expect(cubit.state.isInitial, isTrue);
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.isSuccess, isFalse);
      expect(cubit.state.isError, isFalse);
      expect(cubit.state.hasRoute, isFalse);
      expect(cubit.state.profile, equals(RoutingConstants.profileMopedVn));
    });

    test(
        'previewRouteToPoi resolves GPS location and calculates route seamlessly',
        () async {
      const poi = PoiModel(
        id: 1,
        name: 'Phở Bát Đàn',
        nameAscii: 'Pho Bat Dan',
        lat: 21.0350,
        lon: 105.8450,
        category: 'food',
      );

      await cubit.previewRouteToPoi(poi);

      expect(cubit.state.status, equals(RoutePreviewStatus.success));
      expect(cubit.state.destinationName, equals('Phở Bát Đàn'));
      expect(cubit.state.originName, isNull);
      expect(cubit.state.isOriginCurrentLocation, isTrue);
      expect(cubit.state.origin?.lat, equals(21.0285));
      expect(cubit.state.destination?.lat, equals(21.0350));
      expect(fakeRepo.callCount, equals(1));
    });

    test(
        'previewRouteToCoordinate resolves GPS and calculates route for map click',
        () async {
      await cubit.previewRouteToCoordinate(const LatLng(21.0400, 105.8500));

      expect(cubit.state.status, equals(RoutePreviewStatus.success));
      expect(cubit.state.originName, isNull);
      expect(cubit.state.isOriginCurrentLocation, isTrue);
      expect(cubit.state.destination?.lat, closeTo(21.0400, 0.0001));
      expect(cubit.state.destination?.lon, closeTo(105.8500, 0.0001));
      expect(cubit.state.destinationName, isNull);
      expect(fakeRepo.callCount, equals(1));
    });

    test('getRoute successfully fetches route and emits loading then success',
        () async {
      final future = cubit.getRoute(
        origin: origin,
        destination: destination,
        destinationName: 'Phở Bát Đàn',
      );

      expect(cubit.state.status, equals(RoutePreviewStatus.loading));
      expect(cubit.state.isLoading, isTrue);

      await future;

      expect(cubit.state.status, equals(RoutePreviewStatus.success));
      expect(cubit.state.isSuccess, isTrue);
      expect(cubit.state.hasRoute, isTrue);
      expect(cubit.state.origin, equals(origin));
      expect(cubit.state.destination, equals(destination));
      expect(cubit.state.destinationName, equals('Phở Bát Đàn'));
      expect(cubit.state.routeResult?.distance, equals(3500.0));
      expect(cubit.state.routeResult?.time, equals(420000));
      expect(fakeRepo.callCount, equals(1));
      expect(fakeRepo.lastProfile, equals(RoutingConstants.profileMopedVn));
    });

    test('getRoute emits error when repository returns failure RouteResult',
        () async {
      fakeRepo.customResult = RouteResult.failure('No valid route found');

      await cubit.getRoute(origin: origin, destination: destination);

      expect(cubit.state.status, equals(RoutePreviewStatus.error));
      expect(cubit.state.isError, isTrue);
      expect(cubit.state.errorMessageKey, equals('No valid route found'));
      expect(cubit.state.routeResult, isNull);
    });

    test('getRoute handles exceptions gracefully and emits error state',
        () async {
      fakeRepo.shouldThrow = true;

      await cubit.getRoute(origin: origin, destination: destination);

      expect(cubit.state.status, equals(RoutePreviewStatus.error));
      expect(cubit.state.isError, isTrue);
      expect(cubit.state.errorMessageKey,
          equals(LocaleKeys.routing_error_generic));
      expect(cubit.state.routeResult, isNull);
    });

    test('clearRoute resets state to initial and clears route result',
        () async {
      await cubit.getRoute(origin: origin, destination: destination);
      expect(cubit.state.isSuccess, isTrue);

      cubit.clearRoute();
      expect(cubit.state.status, equals(RoutePreviewStatus.initial));
      expect(cubit.state.isInitial, isTrue);
      expect(cubit.state.hasRoute, isFalse);
      expect(cubit.state.origin, isNull);
      expect(cubit.state.destination, isNull);
    });

    test(
        'Ignores stale response when newer request is dispatched (Generation protection)',
        () async {
      fakeRepo.customRouteHandler = (fromLat, fromLon, toLat, toLon) async {
        if (toLat == 21.0350) {
          // Request 1 takes longer (60ms)
          await Future.delayed(const Duration(milliseconds: 60));
          return const RouteResult(isSuccess: true, distance: 1000.0);
        } else {
          // Request 2 completes quickly (10ms)
          await Future.delayed(const Duration(milliseconds: 10));
          return const RouteResult(isSuccess: true, distance: 2000.0);
        }
      };

      // Start Request 1 (will resolve AFTER Request 2)
      final req1 = cubit.getRoute(
          origin: origin, destination: destination, destinationName: 'Điểm 1');

      // Immediately start Request 2 with different destination
      const dest2 = RoutePoint(lat: 21.05, lon: 105.80);
      final req2 = cubit.getRoute(
          origin: origin, destination: dest2, destinationName: 'Điểm 2');

      await Future.wait([req1, req2]);

      // Cubit should hold the state of Request 2, ignoring the stale Request 1 response
      expect(cubit.state.destinationName, equals('Điểm 2'));
      expect(cubit.state.destination, equals(dest2));
      expect(cubit.state.routeResult?.distance, equals(2000.0));
      expect(cubit.state.requestGeneration, equals(2));
    });
    test('[RTP-02] GPS fallback to defaultLocation when LocationService throws',
        () async {
      final failingRepo = FakeRoutingRepository();
      final failingLocationService = FakeLocationService();
      // Override to always throw on position requests
      failingLocationService.mockPosition = Position(
        latitude: 0,
        longitude: 0,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

      // Create a custom location service that throws
      final throwingCubit = RoutePreviewCubit(
        routingRepository: failingRepo,
        locationService: _ThrowingLocationService(),
      );

      const poi = PoiModel(
        id: 1,
        name: 'Test POI',
        nameAscii: 'Test POI',
        lat: 21.0350,
        lon: 105.8450,
        category: 'food',
      );

      await throwingCubit.previewRouteToPoi(poi);

      // Should use MapConstants.defaultLocation as origin (fallback)
      expect(throwingCubit.state.origin?.lat,
          equals(MapConstants.defaultLocation.latitude));
      expect(throwingCubit.state.origin?.lon,
          equals(MapConstants.defaultLocation.longitude));
      expect(throwingCubit.state.destination?.lat, equals(21.0350));
      expect(failingRepo.callCount, equals(1));

      await throwingCubit.close();
    });

    test('[RTP-05] changeProfile auto-recalculates route when profile changes',
        () async {
      await cubit.getRoute(origin: origin, destination: destination);
      expect(cubit.state.isSuccess, isTrue);
      expect(fakeRepo.callCount, equals(1));

      await cubit.changeProfile('car');

      expect(cubit.state.profile, equals('car'));
      expect(fakeRepo.callCount, equals(2));
      expect(fakeRepo.lastProfile, equals('car'));
    });

    test(
        '[RTP-06] changeProfile does NOT recalculate if same profile and route exists',
        () async {
      await cubit.getRoute(origin: origin, destination: destination);
      expect(cubit.state.isSuccess, isTrue);
      expect(fakeRepo.callCount, equals(1));

      // Same profile → should NOT call API again
      await cubit.changeProfile(RoutingConstants.profileMopedVn);

      expect(fakeRepo.callCount, equals(1),
          reason: 'Should not recalculate for same profile');
    });

    test(
        '[RTP-07] previewRouteBetweenPoints calculates route between custom endpoints',
        () async {
      const customOrigin = RoutePoint(lat: 10.7769, lon: 106.7009);
      const customDest = RoutePoint(lat: 10.8231, lon: 106.6297);

      await cubit.previewRouteBetweenPoints(
        origin: customOrigin,
        destination: customDest,
        originName: 'Nhà thờ Đức Bà',
        destinationName: 'Sân bay Tân Sơn Nhất',
      );

      expect(cubit.state.isSuccess, isTrue);
      expect(cubit.state.origin?.lat, equals(10.7769));
      expect(cubit.state.destination?.lat, equals(10.8231));
      expect(cubit.state.originName, equals('Nhà thờ Đức Bà'));
      expect(cubit.state.destinationName, equals('Sân bay Tân Sơn Nhất'));
    });

    test(
        '[RTP-08] swapEndpoints reverses origin and destination and recalculates',
        () async {
      const pointA = RoutePoint(lat: 10.7769, lon: 106.7009);
      const pointB = RoutePoint(lat: 10.8231, lon: 106.6297);

      await cubit.previewRouteBetweenPoints(
        origin: pointA,
        destination: pointB,
        originName: 'Điểm A',
        destinationName: 'Điểm B',
      );

      expect(cubit.state.origin?.lat, equals(10.7769));
      expect(cubit.state.destination?.lat, equals(10.8231));
      expect(cubit.state.originName, equals('Điểm A'));
      expect(cubit.state.destinationName, equals('Điểm B'));

      await cubit.swapEndpoints();

      expect(cubit.state.origin?.lat, equals(10.8231));
      expect(cubit.state.destination?.lat, equals(10.7769));
      expect(cubit.state.originName, equals('Điểm B'));
      expect(cubit.state.destinationName, equals('Điểm A'));
      expect(fakeRepo.callCount, equals(2));
    });

    test(
        '[RTP-09] selectAlternativeRoute switches active route without network call',
        () async {
      const route1 = RouteResult(
        isSuccess: true,
        distance: 5000.0,
        time: 600000,
        points: [
          [10.0, 106.0],
          [10.1, 106.1]
        ],
        routeTitle: 'Đường ngắn nhất',
      );
      const route2 = RouteResult(
        isSuccess: true,
        distance: 6200.0,
        time: 550000,
        points: [
          [10.0, 106.0],
          [10.05, 106.05],
          [10.1, 106.1]
        ],
        routeTitle: 'Qua đại lộ (Tránh kẹt xe)',
        isAlternative: true,
      );

      cubit.setAlternativeRoutes([route1, route2], initialIndex: 0);

      expect(cubit.state.alternativeRoutes.length, equals(2));
      expect(cubit.state.hasAlternativeRoutes, isTrue);
      expect(cubit.state.selectedRouteIndex, equals(0));
      expect(cubit.state.currentRoute?.distance, equals(5000.0));

      // Chuyển sang route 2
      cubit.selectAlternativeRoute(1);

      expect(cubit.state.selectedRouteIndex, equals(1));
      expect(cubit.state.currentRoute?.distance, equals(6200.0));
      expect(cubit.state.currentRoute?.routeTitle,
          equals('Qua đại lộ (Tránh kẹt xe)'));
      expect(fakeRepo.callCount, equals(0),
          reason:
              'Switching alternative route must be 0ms instant without network');
    });

    test(
        '[RTP-10] getRoute populates multiple alternative routes from repository',
        () async {
      const route1 = RouteResult(
        isSuccess: true,
        distance: 5000.0,
        time: 600000,
        points: [
          [10.0, 106.0],
          [10.1, 106.1]
        ],
        routeTitle: 'Nhanh nhất',
      );
      const route2 = RouteResult(
        isSuccess: true,
        distance: 5800.0,
        time: 660000,
        points: [
          [10.0, 106.0],
          [10.05, 106.05],
          [10.1, 106.1]
        ],
        routeTitle: 'Qua đại lộ chính',
        isAlternative: true,
      );

      fakeRepo.customAlternativeRoutes = [route1, route2];

      await cubit.getRoute(
        origin: const RoutePoint(lat: 10.0, lon: 106.0),
        destination: const RoutePoint(lat: 10.1, lon: 106.1),
      );

      expect(cubit.state.isSuccess, isTrue);
      expect(cubit.state.hasAlternativeRoutes, isTrue);
      expect(cubit.state.alternativeRoutes.length, equals(2));
      expect(cubit.state.selectedRouteIndex, equals(0));
      expect(cubit.state.currentRoute?.routeTitle, equals('Nhanh nhất'));
    });
  });
}
