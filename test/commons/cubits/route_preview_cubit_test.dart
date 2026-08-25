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
  Future<RouteResult> Function(double fromLat, double fromLon, double toLat, double toLon)? customRouteHandler;
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
  (double, double) get latLng => (mockPosition.latitude, mockPosition.longitude);

  @override
  Stream<Position> get positionStream => Stream.value(mockPosition);

  @override
  Future<Position> getCurrentPosition() async => mockPosition;

  @override
  Future<Position?> getLastKnownPosition() async => mockPosition;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async => LocationPermission.always;

  @override
  Future<LocationPermission> requestPermission() async => LocationPermission.always;

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

    test('previewRouteToPoi resolves GPS location and calculates route seamlessly', () async {
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
      expect(cubit.state.origin?.lat, equals(21.0285));
      expect(cubit.state.destination?.lat, equals(21.0350));
      expect(fakeRepo.callCount, equals(1));
    });

    test('previewRouteToCoordinate resolves GPS and calculates route for map click', () async {
      await cubit.previewRouteToCoordinate(const LatLng(21.0400, 105.8500));

      expect(cubit.state.status, equals(RoutePreviewStatus.success));
      expect(cubit.state.destination?.lat, closeTo(21.0400, 0.0001));
      expect(cubit.state.destination?.lon, closeTo(105.8500, 0.0001));
      expect(cubit.state.destinationName, isNull);
      expect(fakeRepo.callCount, equals(1));
    });

    test('getRoute successfully fetches route and emits loading then success', () async {
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

    test('getRoute emits error when repository returns failure RouteResult', () async {
      fakeRepo.customResult = RouteResult.failure('No valid route found');

      await cubit.getRoute(origin: origin, destination: destination);

      expect(cubit.state.status, equals(RoutePreviewStatus.error));
      expect(cubit.state.isError, isTrue);
      expect(cubit.state.errorMessageKey, equals('No valid route found'));
      expect(cubit.state.routeResult, isNull);
    });

    test('getRoute handles exceptions gracefully and emits error state', () async {
      fakeRepo.shouldThrow = true;

      await cubit.getRoute(origin: origin, destination: destination);

      expect(cubit.state.status, equals(RoutePreviewStatus.error));
      expect(cubit.state.isError, isTrue);
      expect(cubit.state.errorMessageKey, equals(LocaleKeys.routing_error_generic));
      expect(cubit.state.routeResult, isNull);
    });

    test('clearRoute resets state to initial and clears route result', () async {
      await cubit.getRoute(origin: origin, destination: destination);
      expect(cubit.state.isSuccess, isTrue);

      cubit.clearRoute();
      expect(cubit.state.status, equals(RoutePreviewStatus.initial));
      expect(cubit.state.isInitial, isTrue);
      expect(cubit.state.hasRoute, isFalse);
      expect(cubit.state.origin, isNull);
      expect(cubit.state.destination, isNull);
    });

    test('Ignores stale response when newer request is dispatched (Generation protection)', () async {
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
      final req1 = cubit.getRoute(origin: origin, destination: destination, destinationName: 'Điểm 1');

      // Immediately start Request 2 with different destination
      const dest2 = RoutePoint(lat: 21.05, lon: 105.80);
      final req2 = cubit.getRoute(origin: origin, destination: dest2, destinationName: 'Điểm 2');

      await Future.wait([req1, req2]);

      // Cubit should hold the state of Request 2, ignoring the stale Request 1 response
      expect(cubit.state.destinationName, equals('Điểm 2'));
      expect(cubit.state.destination, equals(dest2));
      expect(cubit.state.routeResult?.distance, equals(2000.0));
      expect(cubit.state.requestGeneration, equals(2));
    });
  });
}
