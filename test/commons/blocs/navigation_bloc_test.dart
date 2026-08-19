import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

class MockRoutingRepository implements IRoutingRepository {
  RouteResult nextCalculateResult = const RouteResult(
    isSuccess: true,
    distance: 1500.0,
    time: 180000,
    points: [
      [10.7730, 106.6990],
      [10.7750, 106.7010],
      [10.7766, 106.7032],
    ],
  );

  int calculateRouteCallCount = 0;
  double? lastFromLat;
  double? lastFromLon;
  double? lastToLat;
  double? lastToLon;
  String? lastVehicleProfile;
  Duration delay = Duration.zero;

  @override
  Future<RouteResult> calculateRoute({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    String? vehicleProfile,
  }) async {
    calculateRouteCallCount++;
    lastFromLat = fromLat;
    lastFromLon = fromLon;
    lastToLat = toLat;
    lastToLon = toLon;
    lastVehicleProfile = vehicleProfile;

    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    return nextCalculateResult;
  }

  @override
  Future<bool> initializeEngine(String graphPath) async => true;

  @override
  Future<bool> isEngineReady() async => true;

  @override
  Future<bool> dispose() async => true;
}

class MockLocationService implements ILocationService {
  final StreamController<Position> _controller =
      StreamController<Position>.broadcast();

  void emitPosition(Position pos) {
    _controller.add(pos);
  }

  @override
  Position get position => Position(
        longitude: 106.6980,
        latitude: 10.7725,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 10.0,
        altitudeAccuracy: 1.0,
        heading: 90.0,
        headingAccuracy: 1.0,
        speed: 8.33,
        speedAccuracy: 1.0,
      );

  @override
  (double, double) get latLng => (10.7725, 106.6980);

  @override
  Stream<Position> get positionStream => _controller.stream;

  @override
  Future<Position> getCurrentPosition() async => position;

  @override
  Future<Position?> getLastKnownPosition() async => position;

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

  void dispose() {
    _controller.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NavigationBloc Unit & Concurrency Tests', () {
    late MockRoutingRepository mockRoutingRepo;
    late MockLocationService mockLocationService;
    late NavigationBloc bloc;

    const sampleInitialRoute = RouteResult(
      isSuccess: true,
      distance: 3000.0,
      time: 360000,
      points: [
        [10.7725, 106.6980], // Bến Thành
        [10.7738, 106.6998], // Lê Lợi - Pasteur
        [10.7766, 106.7032], // Nhà hát TP
      ],
      instructions: [
        RouteInstruction(
          text: 'Đi thẳng trên đường Lê Lợi',
          streetName: 'Lê Lợi',
          distance: 500.0,
          time: 60000,
          sign: 0,
          points: [
            [10.7725, 106.6980],
            [10.7738, 106.6998],
          ],
        ),
      ],
    );

    const origin = RoutePoint(lat: 10.7725, lon: 106.6980);
    const destination = RoutePoint(lat: 10.7766, lon: 106.7032);

    setUp(() {
      mockRoutingRepo = MockRoutingRepository();
      mockLocationService = MockLocationService();
      bloc = NavigationBloc(
        routingRepository: mockRoutingRepo,
        locationService: mockLocationService,
      );
    });

    tearDown(() async {
      await bloc.close();
      mockLocationService.dispose();
    });

    test('Initial state is NavigationStatus.initial', () {
      expect(bloc.state.status, equals(NavigationStatus.initial));
      expect(bloc.state.isNavigating, isFalse);
      expect(bloc.state.hasRoute, isFalse);
      expect(bloc.state.rerouteCount, equals(0));
    });

    test('StartNavigation transitions state to navigating and listens to GPS updates', () async {
      bloc.add(const StartNavigation(
        initialRoute: sampleInitialRoute,
        origin: origin,
        destination: destination,
        destinationName: 'Nhà hát Thành Phố',
      ));

      await expectLater(
        bloc.stream,
        emits(predicate<NavigationState>((state) {
          return state.status == NavigationStatus.navigating &&
              state.destinationName == 'Nhà hát Thành Phố' &&
              state.currentRoute == sampleInitialRoute &&
              state.isNavigating == true &&
              state.currentSegmentIndex == 0 &&
              state.isOffRoute == false;
        })),
      );
    });

    test('LocationUpdated on-route updates vehicle coordinates and advances segment index without rerouting', () async {
      bloc.add(const StartNavigation(
        initialRoute: sampleInitialRoute,
        origin: origin,
        destination: destination,
        destinationName: 'Nhà hát Thành Phố',
      ));
      await Future.delayed(const Duration(milliseconds: 10));

      // Gửi tọa độ GPS di chuyển hợp lệ trên đường Lê Lợi (gần segment 0)
      bloc.add(const LocationUpdated(
        latitude: 10.7729,
        longitude: 106.6985,
        speed: 8.33, // ~30 km/h
        heading: 45.0,
      ));

      await expectLater(
        bloc.stream,
        emits(predicate<NavigationState>((state) {
          return state.status == NavigationStatus.navigating &&
              state.currentLat == 10.7729 &&
              state.currentLon == 106.6985 &&
              state.currentSpeedKmh != null &&
              state.currentSpeedKmh! > 29.0 &&
              state.isOffRoute == false &&
              mockRoutingRepo.calculateRouteCallCount == 0;
        })),
      );
    });

    test('LocationUpdated off-route (>50m) triggers auto-reroute and updates route', () async {
      const reroutedRoute = RouteResult(
        isSuccess: true,
        distance: 2200.0,
        time: 250000,
        points: [
          [10.7760, 106.6970], // Vị trí mới lệch hẳn về Pasteur
          [10.7770, 106.7000],
          [10.7766, 106.7032], // Đích
        ],
      );
      mockRoutingRepo.nextCalculateResult = reroutedRoute;

      bloc.add(const StartNavigation(
        initialRoute: sampleInitialRoute,
        origin: origin,
        destination: destination,
        destinationName: 'Nhà hát Thành Phố',
      ));
      await Future.delayed(const Duration(milliseconds: 10));

      // Gửi vị trí lệch hẳn sang đường Nam Kỳ Khởi Nghĩa (>150m)
      bloc.add(const LocationUpdated(
        latitude: 10.7760,
        longitude: 106.6970,
        speed: 7.0,
        heading: 90.0,
      ));

      // Kỳ vọng phát hiện off-route -> chuyển sang rerouting -> hoàn tất reroute thành công
      await expectLater(
        bloc.stream,
        emitsInOrder([
          // 1. Phát hiện off-route
          predicate<NavigationState>((state) =>
              state.isOffRoute == true && state.distanceToRoute > 50.0),
          // 2. Chuyển trạng thái rerouting
          predicate<NavigationState>((state) =>
              state.status == NavigationStatus.rerouting &&
              state.isRerouting == true &&
              state.messageKey == LocaleKeys.routing_rerouting),
          // 3. Nhận route mới thành công
          predicate<NavigationState>((state) =>
              state.status == NavigationStatus.navigating &&
              state.currentRoute == reroutedRoute &&
              state.isOffRoute == false &&
              state.isRerouting == false &&
              state.rerouteCount == 1 &&
              state.messageKey == LocaleKeys.routing_reroute_success),
        ]),
      );

      expect(mockRoutingRepo.calculateRouteCallCount, equals(1));
      expect(mockRoutingRepo.lastFromLat, equals(10.7760));
      expect(mockRoutingRepo.lastFromLon, equals(106.6970));
      expect(mockRoutingRepo.lastToLat, equals(destination.lat));
      expect(mockRoutingRepo.lastToLon, equals(destination.lon));
    });

    test('LocationUpdated within 20m of destination marks status as arrived', () async {
      bloc.add(const StartNavigation(
        initialRoute: sampleInitialRoute,
        origin: origin,
        destination: destination,
        destinationName: 'Nhà hát Thành Phố',
      ));
      await Future.delayed(const Duration(milliseconds: 10));

      // Vị trí rất sát điểm đích (< 10m)
      bloc.add(LocationUpdated(
        latitude: destination.lat + 0.00005,
        longitude: destination.lon + 0.00005,
        speed: 1.0,
      ));

      await expectLater(
        bloc.stream,
        emits(predicate<NavigationState>((state) {
          return state.status == NavigationStatus.arrived &&
              state.isOffRoute == false;
        })),
      );
    });

    test('RerouteRequested restartable transformer cancels in-flight stale requests when rapid updates occur', () async {
      mockRoutingRepo.delay = const Duration(milliseconds: 100);

      bloc.add(const StartNavigation(
        initialRoute: sampleInitialRoute,
        origin: origin,
        destination: destination,
      ));
      await Future.delayed(const Duration(milliseconds: 10));

      // Gửi request reroute 1
      bloc.add(const RerouteRequested(
        currentPosition: RoutePoint(lat: 10.7750, lon: 106.6970),
      ));

      // Ngay sau đó gửi request reroute 2 trước khi request 1 xong
      await Future.delayed(const Duration(milliseconds: 20));
      bloc.add(const RerouteRequested(
        currentPosition: RoutePoint(lat: 10.7755, lon: 106.6975),
      ));

      // Đợi hoàn tất
      await Future.delayed(const Duration(milliseconds: 250));

      // Điểm xuất phát cuối cùng được tính phải là của request 2
      expect(bloc.state.status, equals(NavigationStatus.navigating));
      expect(bloc.state.origin?.lat, equals(10.7755));
      expect(bloc.state.origin?.lon, equals(106.6975));
      expect(bloc.state.isRerouting, isFalse);
    });

    test('StopNavigation cancels subscription and resets state to stopped', () async {
      bloc.add(const StartNavigation(
        initialRoute: sampleInitialRoute,
        origin: origin,
        destination: destination,
      ));
      await Future.delayed(const Duration(milliseconds: 10));

      bloc.add(const StopNavigation());

      await expectLater(
        bloc.stream,
        emits(predicate<NavigationState>((state) {
          return state.status == NavigationStatus.stopped &&
              state.isNavigating == false;
        })),
      );
    });

    test('Reroute failure gracefully retains navigation and sets error message', () async {
      mockRoutingRepo.nextCalculateResult = RouteResult.failure('Engine timeout');

      bloc.add(const StartNavigation(
        initialRoute: sampleInitialRoute,
        origin: origin,
        destination: destination,
      ));
      await Future.delayed(const Duration(milliseconds: 10));

      bloc.add(const RerouteRequested(
        currentPosition: RoutePoint(lat: 10.7750, lon: 106.6970),
      ));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<NavigationState>((state) =>
              state.status == NavigationStatus.rerouting &&
              state.isRerouting == true),
          predicate<NavigationState>((state) =>
              state.status == NavigationStatus.navigating &&
              state.isRerouting == false &&
              state.errorMessageKey == 'Engine timeout'),
        ]),
      );
    });

    test('Turn-by-turn instruction progress is initialized and advances with GPS stream', () async {
      const multiStepRoute = RouteResult(
        isSuccess: true,
        distance: 1000.0,
        time: 120000,
        points: [
          [10.7725, 106.6980],
          [10.7750, 106.6980],
          [10.7750, 106.7020],
        ],
        instructions: [
          RouteInstruction(
            text: 'Đi thẳng trên Lê Lợi',
            streetName: 'Lê Lợi',
            distance: 400.0,
            time: 50000,
            sign: 0,
            points: [
              [10.7725, 106.6980],
              [10.7750, 106.6980],
            ],
          ),
          RouteInstruction(
            text: 'Rẽ phải vào Đồng Khởi',
            streetName: 'Đồng Khởi',
            distance: 600.0,
            time: 70000,
            sign: 2,
            points: [
              [10.7750, 106.6980],
              [10.7750, 106.7020],
            ],
          ),
        ],
      );

      bloc.add(const StartNavigation(
        initialRoute: multiStepRoute,
        origin: origin,
        destination: destination,
      ));

      await expectLater(
        bloc.stream,
        emits(predicate<NavigationState>((state) {
          return state.status == NavigationStatus.navigating &&
              state.currentInstructionIndex == 0 &&
              state.currentInstruction?.text == 'Đi thẳng trên Lê Lợi' &&
              state.nextInstruction?.text == 'Rẽ phải vào Đồng Khởi' &&
              state.remainingDistance == 1000.0 &&
              state.isPreAnnounced == false;
        })),
      );

      // GPS di chuyển đến cách ngã rẽ ~150m (Pre-announce <= 200m)
      bloc.add(const LocationUpdated(
        latitude: 10.7738,
        longitude: 106.6980,
        speed: 10.0,
      ));

      await expectLater(
        bloc.stream,
        emits(predicate<NavigationState>((state) {
          return state.currentInstructionIndex == 0 &&
              state.isPreAnnounced == true &&
              state.distanceToNextInstruction <= 200.0;
        })),
      );

      // GPS di chuyển đến sát ngã rẽ (<30m) -> tự động advance sang instruction 1
      bloc.add(const LocationUpdated(
        latitude: 10.7749,
        longitude: 106.6980,
        speed: 5.0,
      ));

      await expectLater(
        bloc.stream,
        emits(predicate<NavigationState>((state) {
          return state.currentInstructionIndex == 1 &&
              state.currentInstruction?.text == 'Rẽ phải vào Đồng Khởi' &&
              state.nextInstruction == null;
        })),
      );
    });

    test('Arriving at destination generates TripSummary with hasArrived true', () async {
      bloc.add(const StartNavigation(
        initialRoute: sampleInitialRoute,
        origin: origin,
        destination: destination,
        destinationName: 'Nhà hát Thành phố',
      ));

      await expectLater(
        bloc.stream,
        emits(predicate<NavigationState>((s) => s.status == NavigationStatus.navigating)),
      );

      // Điểm gần đích (< 20m)
      bloc.add(const LocationUpdated(
        latitude: 10.77659,
        longitude: 106.70319,
        speed: 8.5, // ~30.6 km/h
      ));

      await expectLater(
        bloc.stream,
        emits(predicate<NavigationState>((s) {
          return s.status == NavigationStatus.arrived &&
              s.tripSummary != null &&
              s.tripSummary!.hasArrived == true &&
              s.tripSummary!.destinationName == 'Nhà hát Thành phố' &&
              s.tripSummary!.topSpeedKmh > 0;
        })),
      );
    });

    test('StopNavigation generates TripSummary with hasArrived false and Stop status', () async {
      bloc.add(const StartNavigation(
        initialRoute: sampleInitialRoute,
        origin: origin,
        destination: destination,
        destinationName: 'Nhà hát Thành phố',
      ));

      await expectLater(
        bloc.stream,
        emits(predicate<NavigationState>((s) => s.status == NavigationStatus.navigating)),
      );

      bloc.add(const LocationUpdated(
        latitude: 10.7740,
        longitude: 106.7000,
        speed: 10.0, // 36 km/h
      ));

      await expectLater(
        bloc.stream,
        emits(predicate<NavigationState>((s) => s.currentSpeedKmh != null)),
      );

      bloc.add(const StopNavigation());

      await expectLater(
        bloc.stream,
        emits(predicate<NavigationState>((s) {
          return s.status == NavigationStatus.stopped &&
              s.tripSummary != null &&
              s.tripSummary!.hasArrived == false &&
              s.tripSummary!.destinationName == 'Nhà hát Thành phố' &&
              s.tripSummary!.topSpeedKmh >= 35.0;
        })),
      );
    });

    test('Stopping immediately after start produces TripSummary with 0 distance and 0 avg speed', () async {
      bloc.add(const StartNavigation(
        initialRoute: sampleInitialRoute,
        origin: origin,
        destination: destination,
        destinationName: 'Nhà hát Thành phố',
      ));

      await expectLater(
        bloc.stream,
        emits(predicate<NavigationState>((s) => s.status == NavigationStatus.navigating)),
      );

      bloc.add(const StopNavigation());

      await expectLater(
        bloc.stream,
        emits(predicate<NavigationState>((s) {
          return s.status == NavigationStatus.stopped &&
              s.tripSummary != null &&
              s.tripSummary!.hasArrived == false &&
              s.tripSummary!.distanceMeters == 0.0 &&
              s.tripSummary!.avgSpeedKmh == 0.0;
        })),
      );
    });

    test('GPS fixes with poor accuracy (> 35m) are ignored for distance accumulation', () async {
      bloc.add(const StartNavigation(
        initialRoute: sampleInitialRoute,
        origin: origin,
        destination: destination,
        destinationName: 'Nhà hát Thành phố',
      ));

      await expectLater(
        bloc.stream,
        emits(predicate<NavigationState>((s) => s.status == NavigationStatus.navigating)),
      );

      // Điểm 1: GPS chuẩn trên lộ trình (accuracy 5m)
      bloc.add(const LocationUpdated(
        latitude: 10.7725,
        longitude: 106.6980,
        accuracy: 5.0,
      ));

      await expectLater(
        bloc.stream,
        emits(predicate<NavigationState>((s) => s.currentLat == 10.7725)),
      );

      // Điểm 2: Di chuyển hợp lệ trên lộ trình (~90m)
      bloc.add(const LocationUpdated(
        latitude: 10.7730,
        longitude: 106.6987,
        accuracy: 5.0,
      ));

      double recordedDistance = 0.0;
      await expectLater(
        bloc.stream,
        emits(predicate<NavigationState>((s) {
          recordedDistance = s.totalDistanceTraveledMeters;
          return s.currentLat == 10.7730 && s.totalDistanceTraveledMeters > 0;
        })),
      );

      // Điểm 3: GPS nhiễu/kém (accuracy 60m > 35m) -> Vẫn cập nhật UI tọa độ nhưng không cộng dồn distance
      bloc.add(const LocationUpdated(
        latitude: 10.7734,
        longitude: 106.6992,
        accuracy: 60.0,
      ));

      await expectLater(
        bloc.stream,
        emits(predicate<NavigationState>((s) {
          return s.currentLat == 10.7734 &&
              s.currentAccuracy == 60.0 &&
              s.totalDistanceTraveledMeters == recordedDistance &&
              s.isRerouting == false;
        })),
      );
      expect(mockRoutingRepo.calculateRouteCallCount, equals(0));
    });

    test('GPS jumps excessively large (> 200m) are ignored for distance accumulation', () async {
      bloc.add(const StartNavigation(
        initialRoute: sampleInitialRoute,
        origin: origin,
        destination: destination,
        destinationName: 'Nhà hát Thành phố',
      ));

      await expectLater(
        bloc.stream,
        emits(predicate<NavigationState>((s) => s.status == NavigationStatus.navigating)),
      );

      // Điểm 1: GPS chuẩn trên lộ trình (accuracy 5m)
      bloc.add(const LocationUpdated(
        latitude: 10.7725,
        longitude: 106.6980,
        accuracy: 5.0,
      ));

      await expectLater(
        bloc.stream,
        emits(predicate<NavigationState>((s) => s.currentLat == 10.7725)),
      );

      // Điểm 2: Di chuyển hợp lệ trên lộ trình (~90m)
      bloc.add(const LocationUpdated(
        latitude: 10.7730,
        longitude: 106.6987,
        accuracy: 5.0,
      ));

      double recordedDistance = 0.0;
      await expectLater(
        bloc.stream,
        emits(predicate<NavigationState>((s) {
          recordedDistance = s.totalDistanceTraveledMeters;
          return s.currentLat == 10.7730 && s.totalDistanceTraveledMeters > 0;
        })),
      );

      // Điểm 3: Nhảy đột biến > 200m (~500m tới gần đích) trong 1 tick
      bloc.add(const LocationUpdated(
        latitude: 10.7766,
        longitude: 106.7032,
        accuracy: 5.0,
      ));

      await expectLater(
        bloc.stream,
        emits(predicate<NavigationState>((s) {
          return s.currentLat == 10.7766 &&
              s.totalDistanceTraveledMeters == recordedDistance;
        })),
      );
    });

    test('ClearNavigation resets navigation state back to initial', () async {
      bloc.add(const StartNavigation(
        initialRoute: sampleInitialRoute,
        origin: origin,
        destination: destination,
        destinationName: 'Nhà hát Thành phố',
      ));
      await expectLater(
        bloc.stream,
        emits(predicate<NavigationState>(
          (s) => s.status == NavigationStatus.navigating,
        )),
      );

      bloc.add(const StopNavigation());
      await expectLater(
        bloc.stream,
        emits(predicate<NavigationState>(
          (s) => s.status == NavigationStatus.stopped && s.tripSummary != null,
        )),
      );

      bloc.add(const ClearNavigation());
      await expectLater(
        bloc.stream,
        emits(predicate<NavigationState>(
          (s) =>
              s.status == NavigationStatus.initial && s.tripSummary == null,
        )),
      );
    });
  });
}
