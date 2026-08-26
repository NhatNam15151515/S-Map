import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

class MockRoutingRepository implements IRoutingRepository {
  RouteResult nextCalculateResult = const RouteResult(
    isSuccess: true,
    distance: 2000.0,
    time: 240000,
    points: [
      [10.7769, 106.7009],
      [10.7800, 106.7030],
      [10.7820, 106.7050],
    ],
  );

  int calculateRouteCallCount = 0;

  @override
  Future<RouteResult> calculateRoute({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    String? vehicleProfile,
  }) async {
    calculateRouteCallCount++;
    return nextCalculateResult;
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

class MockLocationService implements ILocationService {
  final StreamController<Position> _controller =
      StreamController<Position>.broadcast();

  void emitPosition(Position pos) {
    _controller.add(pos);
  }

  @override
  Position get position => Position(
        longitude: 106.7009,
        latitude: 10.7769,
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
  (double, double) get latLng => (10.7769, 106.7009);

  @override
  Stream<Position> get positionStream => _controller.stream;

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
      _controller.stream;

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

  @override
  Future<bool> isBatteryOptimizationIgnored() async => true;

  @override
  Future<bool> requestIgnoreBatteryOptimization() async => true;

  @override
  Future<bool> requestNotificationPermission() async => true;
}

class MockTripRepository implements ITripRepository {
  final List<TripRecordModel> savedTrips = [];

  @override
  Future<void> saveTrip(TripRecordModel trip) async {
    savedTrips.add(trip);
  }

  @override
  Future<List<TripRecordModel>> getTrips() async => savedTrips;

  @override
  Future<TripRecordModel?> getTripById(String id) async => null;

  @override
  Future<void> deleteTrip(String id) async {}

  @override
  Future<void> clearAllTrips() async {
    savedTrips.clear();
  }

  @override
  Future<void> markTripAsSynced(String id) async {}

  @override
  Stream<List<TripRecordModel>> watchTrips() => const Stream.empty();
}

class MockActiveTripService implements IActiveTripService {
  ActiveTripSnapshot? currentSnapshot;
  int saveCount = 0;
  int clearCount = 0;
  bool shouldThrowOnSave = false;

  @override
  Future<void> init() async {}

  @override
  Future<void> saveActiveSession(ActiveTripSnapshot snapshot) async {
    if (shouldThrowOnSave) {
      throw Exception('Storage full exception simulated');
    }
    saveCount++;
    currentSnapshot = snapshot;
  }

  @override
  Future<ActiveTripSnapshot?> getActiveSession() async => currentSnapshot;

  @override
  Future<void> clearActiveSession() async {
    clearCount++;
    currentSnapshot = null;
  }

  @override
  Future<bool> hasActiveSession() async => currentSnapshot != null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockRoutingRepository mockRoutingRepo;
  late MockTripRepository mockTripRepo;
  late MockLocationService mockLocationService;
  late MockActiveTripService mockActiveTripService;
  late NavigationBloc bloc;

  const sampleRoute = RouteResult(
    isSuccess: true,
    distance: 3000.0,
    time: 360000,
    points: [
      [10.7769, 106.7009],
      [10.7790, 106.7030],
      [10.7820, 106.7050],
    ],
    instructions: [
      RouteInstruction(
        text: 'Đi thẳng trên Lê Lợi',
        streetName: 'Lê Lợi',
        distance: 1000.0,
        time: 120000,
        sign: 0,
        points: [
          [10.7769, 106.7009],
          [10.7790, 106.7030],
        ],
      ),
      RouteInstruction(
        text: 'Rẽ phải vào Nguyễn Huệ',
        streetName: 'Nguyễn Huệ',
        distance: 2000.0,
        time: 240000,
        sign: 2,
        points: [
          [10.7790, 106.7030],
          [10.7820, 106.7050],
        ],
      ),
    ],
  );

  final sampleSnapshot = ActiveTripSnapshot(
    origin: const RoutePoint(lat: 10.7769, lon: 106.7009),
    destination: const RoutePoint(lat: 10.7820, lon: 106.7050),
    destinationName: 'Landmark 81',
    profile: RoutingConstants.profileMopedVn,
    initialRoute: sampleRoute,
    currentSegmentIndex: 0,
    currentInstructionIndex: 0,
    tripStartTime: DateTime.now().subtract(const Duration(minutes: 10)),
    lastSavedTime: DateTime.now(),
    totalDistanceTraveledMeters: 850.0,
    maxSpeedKmh: 45.0,
    speedSampleSum: 700.0,
    speedSampleCount: 20,
    lastKnownLat: 10.7780,
    lastKnownLon: 106.7020,
  );

  setUp(() {
    mockRoutingRepo = MockRoutingRepository();
    mockTripRepo = MockTripRepository();
    mockLocationService = MockLocationService();
    mockActiveTripService = MockActiveTripService();

    bloc = NavigationBloc(
      routingRepository: mockRoutingRepo,
      tripRepository: mockTripRepo,
      locationService: mockLocationService,
      activeTripService: mockActiveTripService,
    );
  });

  tearDown(() async {
    await bloc.close();
  });

  group('NavigationBloc Resume & Active Session Tests', () {
    test('CheckActiveSession emits state with pendingResumeSession when active session exists', () async {
      mockActiveTripService.currentSnapshot = sampleSnapshot;

      bloc.add(const CheckActiveSession());
      await pumpEventQueue();

      expect(bloc.state.pendingResumeSession, equals(sampleSnapshot));
    });

    test('ResumeNavigation restores full metrics and transitions to navigating', () async {
      mockActiveTripService.currentSnapshot = sampleSnapshot;

      bloc.add(ResumeNavigation(sampleSnapshot));
      await pumpEventQueue();

      expect(bloc.state.status, equals(NavigationStatus.navigating));
      expect(bloc.state.isNavigating, isTrue);
      expect(bloc.state.destinationName, equals('Landmark 81'));
      expect(bloc.state.origin, equals(sampleSnapshot.origin));
      expect(bloc.state.destination, equals(sampleSnapshot.destination));
      expect(bloc.state.totalDistanceTraveledMeters, equals(850.0));
      expect(bloc.state.maxSpeedKmh, equals(45.0));
      expect(bloc.state.tripStartTime, equals(sampleSnapshot.tripStartTime));
      expect(bloc.state.pendingResumeSession, isNull);
    });

    test('ResumeNavigation followed by off-route GPS triggers reroute calculation', () async {
      mockActiveTripService.currentSnapshot = sampleSnapshot;

      bloc.add(ResumeNavigation(sampleSnapshot));
      await pumpEventQueue();

      expect(bloc.state.status, equals(NavigationStatus.navigating));
      expect(mockRoutingRepo.calculateRouteCallCount, equals(0));

      // Emit a GPS position clearly far away from the resumed route (> 50m)
      mockLocationService.emitPosition(
        Position(
          latitude: 10.8000,
          longitude: 106.7300,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 10.0,
          altitudeAccuracy: 1.0,
          heading: 90.0,
          headingAccuracy: 1.0,
          speed: 8.33,
          speedAccuracy: 1.0,
        ),
      );
      await pumpEventQueue();

      // Verify routing repository was called for rerouting and state returned to navigating
      expect(mockRoutingRepo.calculateRouteCallCount, equals(1));
      expect(bloc.state.status, equals(NavigationStatus.navigating));
      expect(bloc.state.rerouteCount, equals(1));
      expect(bloc.state.isOffRoute, isFalse);
    });

    test('DiscardActiveSession clears active session from service and state', () async {
      mockActiveTripService.currentSnapshot = sampleSnapshot;
      bloc.add(const CheckActiveSession());
      await pumpEventQueue();
      expect(bloc.state.pendingResumeSession, isNotNull);

      bloc.add(const DiscardActiveSession());
      await pumpEventQueue();

      expect(bloc.state.pendingResumeSession, isNull);
      expect(mockActiveTripService.clearCount, equals(1));
      expect(mockActiveTripService.currentSnapshot, isNull);
    });

    test('StartNavigation auto-saves snapshot periodically and cancels on close', () {
      fakeAsync((async) {
        final localBloc = NavigationBloc(
          routingRepository: mockRoutingRepo,
          tripRepository: mockTripRepo,
          locationService: mockLocationService,
          activeTripService: mockActiveTripService,
        );

        localBloc.add(const StartNavigation(
          initialRoute: sampleRoute,
          origin: RoutePoint(lat: 10.7769, lon: 106.7009),
          destination: RoutePoint(lat: 10.7820, lon: 106.7050),
          destinationName: 'Landmark 81',
        ));
        async.flushMicrotasks();

        expect(mockActiveTripService.saveCount, equals(1));
        expect(mockActiveTripService.currentSnapshot, isNotNull);
        expect(mockActiveTripService.currentSnapshot!.destinationName, equals('Landmark 81'));

        // Advance 30 seconds -> periodic auto-save triggers SaveActiveSessionSnapshot
        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();
        expect(mockActiveTripService.saveCount, equals(2));

        // Advance another 30 seconds -> triggers again
        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();
        expect(mockActiveTripService.saveCount, equals(3));

        // Close bloc -> timer must be cancelled
        localBloc.close();
        async.flushMicrotasks();

        final countAfterClose = mockActiveTripService.saveCount;
        async.elapse(const Duration(seconds: 60));
        async.flushMicrotasks();
        expect(mockActiveTripService.saveCount, equals(countAfterClose));
      });
    });

    test('StopNavigation clears active trip session from service', () async {
      bloc.add(const StartNavigation(
        initialRoute: sampleRoute,
        origin: RoutePoint(lat: 10.7769, lon: 106.7009),
        destination: RoutePoint(lat: 10.7820, lon: 106.7050),
        destinationName: 'Landmark 81',
      ));
      await pumpEventQueue();

      bloc.add(const StopNavigation());
      await pumpEventQueue();

      expect(mockActiveTripService.clearCount, greaterThanOrEqualTo(1));
      expect(mockActiveTripService.currentSnapshot, isNull);
    });

    test('ClearNavigation clears active trip session from service', () async {
      bloc.add(const StartNavigation(
        initialRoute: sampleRoute,
        origin: RoutePoint(lat: 10.7769, lon: 106.7009),
        destination: RoutePoint(lat: 10.7820, lon: 106.7050),
        destinationName: 'Landmark 81',
      ));
      await pumpEventQueue();

      bloc.add(const ClearNavigation());
      await pumpEventQueue();

      expect(mockActiveTripService.clearCount, greaterThanOrEqualTo(1));
      expect(mockActiveTripService.currentSnapshot, isNull);
    });

    test('Storage failure during SaveActiveSessionSnapshot emits storage warning error message', () async {
      bloc.add(const StartNavigation(
        initialRoute: sampleRoute,
        origin: RoutePoint(lat: 10.7769, lon: 106.7009),
        destination: RoutePoint(lat: 10.7820, lon: 106.7050),
        destinationName: 'Landmark 81',
      ));
      await pumpEventQueue();

      mockActiveTripService.shouldThrowOnSave = true;
      bloc.add(const SaveActiveSessionSnapshot());
      await pumpEventQueue();

      expect(bloc.state.errorMessageKey, equals(LocaleKeys.routing_storage_warning));
    });
  });
}
