import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/repos/repos.dart';

class MockRoutingService implements IRoutingService {
  bool initCalled = false;
  int initCallCount = 0;
  Completer<void>? initStartedCompleter;
  Completer<bool>? initCompleter;
  String? lastGraphPath;
  bool routeCalled = false;
  String? lastProfile;
  bool snapCalled = false;
  double? lastSnapLat;
  double? lastSnapLon;
  bool disposeCalled = false;
  bool readyState = false;
  bool initSuccess;

  final RouteResult mockResult;
  final SnappedRoadPoint? customSnapResult;

  MockRoutingService({
    RouteResult? customResult,
    this.customSnapResult,
    this.initSuccess = true,
  }) : mockResult = customResult ??
            const RouteResult(
              isSuccess: true,
              distance: 3500.0,
              time: 420000,
              points: [
                [21.0285, 105.8542],
                [21.0330, 105.8200],
                [21.0380, 105.7830],
              ],
              bbox: [105.7830, 21.0285, 105.8542, 21.0380],
              instructions: [
                RouteInstruction(
                  text: 'Đi thẳng trên Tràng Thi',
                  streetName: 'Tràng Thi',
                  distance: 800.0,
                  time: 120000,
                  sign: 0,
                  points: [
                    [21.0285, 105.8542],
                    [21.0300, 105.8450],
                  ],
                ),
                RouteInstruction(
                  text: 'Rẽ phải vào Kim Mã',
                  streetName: 'Kim Mã',
                  distance: 2700.0,
                  time: 300000,
                  sign: 2,
                  points: [
                    [21.0300, 105.8450],
                    [21.0380, 105.7830],
                  ],
                ),
              ],
              calculationTimeMs: 18,
            );

  @override
  Future<bool> initGraphHopper(String graphPath) async {
    initCalled = true;
    initCallCount++;
    lastGraphPath = graphPath;
    if (initStartedCompleter != null && !initStartedCompleter!.isCompleted) {
      initStartedCompleter!.complete();
    }
    if (initCompleter != null) {
      final res = await initCompleter!.future;
      readyState = res;
      return res;
    }
    readyState = initSuccess;
    return initSuccess;
  }

  Future<RouteResult> Function(double, double, double, double, String?)?
      customRouteHandler;
  Future<SnappedRoadPoint> Function(double, double)? customSnapHandler;

  @override
  Future<RouteResult> getRoute({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    String? vehicleProfile,
  }) async {
    routeCalled = true;
    lastProfile = vehicleProfile;
    if (customRouteHandler != null) {
      return customRouteHandler!(
          fromLat, fromLon, toLat, toLon, vehicleProfile);
    }
    // Simulate real-world invocation delay
    await Future.delayed(const Duration(milliseconds: 2));
    return mockResult;
  }

  @override
  Future<SnappedRoadPoint> snapToRoad({
    required double lat,
    required double lon,
  }) async {
    snapCalled = true;
    lastSnapLat = lat;
    lastSnapLon = lon;
    if (customSnapHandler != null) {
      return customSnapHandler!(lat, lon);
    }
    return customSnapResult ??
        SnappedRoadPoint(
          isSnapped: true,
          originalLat: lat,
          originalLon: lon,
          snappedLat: lat + 0.0001,
          snappedLon: lon + 0.0001,
          streetName: 'Tràng Thi',
          distanceToRoad: 3.2,
          edgeId: 999,
          calculationTimeMs: 1,
        );
  }

  @override
  Future<bool> isInitialized() async => readyState;

  @override
  Future<bool> dispose() async {
    disposeCalled = true;
    readyState = false;
    return true;
  }
}

void main() {
  late MockRoutingService mockService;
  late RoutingRepositoryImpl repository;

  setUp(() {
    mockService = MockRoutingService()..readyState = true;
    repository = RoutingRepositoryImpl(routingService: mockService);
  });

  group('RoutingRepositoryImpl Tests', () {
    test('initializeEngine should forward graph path to service', () async {
      final success = await repository.initializeEngine('/path/to/hanoi.ghz');
      expect(success, isTrue);
      expect(mockService.initCalled, isTrue);
      expect(mockService.lastGraphPath, equals('/path/to/hanoi.ghz'));
    });

    test('calculateRoute should return parsed RouteResult and forward profile with deep assertions', () async {
      final result = await repository.calculateRoute(
        fromLat: 21.0285,
        fromLon: 105.8542,
        toLat: 21.0380,
        toLon: 105.7830,
        vehicleProfile: RoutingConstants.profileMopedVn,
      );

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.distance, equals(3500.0));
      expect(result.time, equals(420000));
      expect(result.calculationTimeMs, equals(18));
      expect(result.bbox, equals([105.7830, 21.0285, 105.8542, 21.0380]));

      // Deep assert points
      expect(result.points.length, equals(3));
      expect(result.points[0], equals([21.0285, 105.8542]));
      expect(result.points[1], equals([21.0330, 105.8200]));
      expect(result.points[2], equals([21.0380, 105.7830]));

      // Deep assert instructions
      expect(result.instructions.length, equals(2));
      final ins1 = result.instructions[0];
      expect(ins1.text, equals('Đi thẳng trên Tràng Thi'));
      expect(ins1.streetName, equals('Tràng Thi'));
      expect(ins1.distance, equals(800.0));
      expect(ins1.time, equals(120000));
      expect(ins1.sign, equals(0));
      expect(ins1.points.length, equals(2));
      expect(ins1.points[0], equals([21.0285, 105.8542]));
      expect(ins1.points[1], equals([21.0300, 105.8450]));

      final ins2 = result.instructions[1];
      expect(ins2.text, equals('Rẽ phải vào Kim Mã'));
      expect(ins2.streetName, equals('Kim Mã'));
      expect(ins2.distance, equals(2700.0));
      expect(ins2.time, equals(300000));
      expect(ins2.sign, equals(2));
      expect(ins2.points.length, equals(2));
      expect(ins2.points[0], equals([21.0300, 105.8450]));
      expect(ins2.points[1], equals([21.0380, 105.7830]));

      expect(mockService.routeCalled, isTrue);
      expect(mockService.lastProfile, equals(RoutingConstants.profileMopedVn));
    });

    test('isEngineReady and dispose lifecycle operations', () async {
      mockService.readyState = false;
      mockService.initSuccess = false;
      expect(await repository.isEngineReady(), isFalse);
      mockService.initSuccess = true;
      await repository.initializeEngine('/path.ghz');
      expect(await repository.isEngineReady(), isTrue);

      final disposed = await repository.dispose();
      expect(disposed, isTrue);
      expect(mockService.disposeCalled, isTrue);
      mockService.initSuccess = false;
      expect(await repository.isEngineReady(), isFalse);
    });

    test('calculateRoute returns failure when engine is uninitialized', () async {
      final failingService = MockRoutingService(initSuccess: false)..readyState = false;
      final failingRepo = RoutingRepositoryImpl(routingService: failingService);

      final result = await failingRepo.calculateRoute(
        fromLat: 10.7844,
        fromLon: 106.6456,
        toLat: 10.7705,
        toLon: 106.6656,
      );

      expect(failingService.routeCalled, isFalse);
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, equals(RoutingConstants.errServiceNotInitialized));
    });

    test('Acceptance Criteria: 20 consecutive route requests execution benchmark', () async {
      final latencies = <int>[];

      for (int i = 0; i < 20; i++) {
        final stopwatch = Stopwatch()..start();
        final result = await repository.calculateRoute(
          fromLat: 21.0285,
          fromLon: 105.8542,
          toLat: 21.0380,
          toLon: 105.7830,
        );
        stopwatch.stop();
        latencies.add(stopwatch.elapsedMilliseconds);

        expect(result.isSuccess, isTrue);
        expect(result.points.isNotEmpty, isTrue);
      }

      final avgLatency = latencies.reduce((a, b) => a + b) / latencies.length;
      expect(avgLatency, lessThan(300.0),
          reason: 'Benchmark failure: 20 requests avg was $avgLatency ms (must be < 300ms)');
    });

    test('AppReposProvider integrates routingRepos instance with DI', () {
      final provider = AppReposProvider(routingRepos: repository);
      expect(provider.routingRepos, equals(repository));
    });

    test('AppReposProvider integrates routingService instance and constructs RoutingRepositoryImpl', () {
      final provider = AppReposProvider(routingService: mockService);
      expect(provider.routingRepos, isNotNull);
    });

    test('AppReposProvider throws ArgumentError when both routingRepos and routingService are omitted', () {
      expect(() => AppReposProvider(), throwsA(isA<ArgumentError>()));
    });
  });


  group('Routing Models Unit & Serialization Tests', () {
    test('RoutePoint equality and conversions', () {
      const p1 = RoutePoint(lat: 21.0285, lon: 105.8542);
      const p2 = RoutePoint(lat: 21.0285, lon: 105.8542);
      const p3 = RoutePoint(lat: 21.0300, lon: 105.8542);

      expect(p1, equals(p2));
      expect(p1 == p3, isFalse);
      expect(p1.toList(), equals([21.0285, 105.8542]));

      final fromListPoint = RoutePoint.fromList(const [21.0285, 105.8542]);
      expect(fromListPoint, equals(p1));

      final fromMapPoint = RoutePoint.fromMap(const {'lat': 21.0285, 'lon': 105.8542});
      expect(fromMapPoint, equals(p1));
    });

    test('RouteInstruction equality and serialization', () {
      const ins = RouteInstruction(
        text: 'Rẽ trái',
        streetName: 'Hai Bà Trưng',
        distance: 200.0,
        time: 30000,
        sign: 1,
        points: [
          [21.02, 105.85],
          [21.03, 105.86],
        ],
      );

      final map = ins.toMap();
      expect(map['text'], equals('Rẽ trái'));
      expect(map['streetName'], equals('Hai Bà Trưng'));
      expect(map['distance'], equals(200.0));
      expect(map['time'], equals(30000));
      expect(map['sign'], equals(1));

      final deserialized = RouteInstruction.fromMap(map);
      expect(deserialized, equals(ins));
    });

    test('RouteResult failure factory and serialization', () {
      final failure = RouteResult.failure('Engine missing', 10);
      expect(failure.isSuccess, isFalse);
      expect(failure.isFailure, isTrue);
      expect(failure.errorMessage, equals('Engine missing'));
      expect(failure.calculationTimeMs, equals(10));

      const success = RouteResult(
        isSuccess: true,
        distance: 1000.0,
        time: 60000,
        points: [
          [21.0, 105.0],
          [21.1, 105.1],
        ],
        bbox: [105.0, 21.0, 105.1, 21.1],
        instructions: [],
        calculationTimeMs: 15,
      );

      final map = success.toMap();
      final deserialized = RouteResult.fromMap(map);
      expect(deserialized, equals(success));
    });

    test('SnappedRoadPoint equality, serialization and notSnapped factory', () {
      final point = SnappedRoadPoint.notSnapped(
        originalLat: 21.0285,
        originalLon: 105.8542,
        errorMessage: 'Not ready',
        calculationTimeMs: 3,
      );

      expect(point.isSnapped, isFalse);
      expect(point.originalLat, equals(21.0285));
      expect(point.originalLon, equals(105.8542));
      expect(point.snappedLat, equals(21.0285));
      expect(point.snappedLon, equals(105.8542));
      expect(point.errorMessage, equals('Not ready'));
      expect(point.calculationTimeMs, equals(3));

      const snapped = SnappedRoadPoint(
        isSnapped: true,
        originalLat: 21.0285,
        originalLon: 105.8542,
        snappedLat: 21.02855,
        snappedLon: 105.85425,
        streetName: 'Tràng Thi',
        distanceToRoad: 4.2,
        edgeId: 456,
        calculationTimeMs: 2,
      );

      final map = snapped.toMap();
      final deserialized = SnappedRoadPoint.fromMap(map);
      expect(deserialized, equals(snapped));
      expect(deserialized.props, equals(snapped.props));
    });
  });

  group('RoutingRepository snapToRoad Tests', () {
    test('snapToRoad forwards to service when engine is ready', () async {
      final result = await repository.snapToRoad(lat: 21.0285, lon: 105.8542);

      expect(mockService.snapCalled, isTrue);
      expect(mockService.lastSnapLat, equals(21.0285));
      expect(mockService.lastSnapLon, equals(105.8542));
      expect(result.isSnapped, isTrue);
      expect(result.streetName, equals('Tràng Thi'));
      expect(result.distanceToRoad, equals(3.2));
    });

    test('snapToRoad returns notSnapped when engine fails auto-init', () async {
      final unreadyService = MockRoutingService(initSuccess: false)..readyState = false;
      final repo = RoutingRepositoryImpl(routingService: unreadyService);

      final result = await repo.snapToRoad(lat: 10.78, lon: 106.65);

      expect(result.isSnapped, isFalse);
      expect(result.originalLat, equals(10.78));
      expect(result.originalLon, equals(106.65));
      expect(result.errorMessage, equals(RoutingConstants.errServiceNotInitialized));
    });

    test('concurrent snapToRoad requests share the same auto-init Future and execute init exactly once', () async {
      final initCompleter = Completer<bool>();
      final sharedService = MockRoutingService()
        ..readyState = false
        ..initCompleter = initCompleter;
      final repo = RoutingRepositoryImpl(routingService: sharedService);

      // Gửi đồng thời 3 request snapToRoad khi chưa init
      final future1 = repo.snapToRoad(lat: 21.0285, lon: 105.8542);
      final future2 = repo.snapToRoad(lat: 21.0300, lon: 105.8550);
      final future3 = repo.snapToRoad(lat: 21.0350, lon: 105.8600);

      // Giải phóng Completer để init hoàn tất thành công
      initCompleter.complete(true);

      final results = await Future.wait([future1, future2, future3]);

      expect(results.length, equals(3));
      expect(sharedService.initCallCount, equals(1));
      for (final res in results) {
        expect(res.isSnapped, isTrue);
        expect(res.streetName, equals('Tràng Thi'));
      }
    });

    test('dispose called during pending auto-init prevents engine from staying active', () async {
      final initStarted = Completer<void>();
      final initCompleter = Completer<bool>();
      final service = MockRoutingService()
        ..readyState = false
        ..initStartedCompleter = initStarted
        ..initCompleter = initCompleter;
      final repo = RoutingRepositoryImpl(routingService: service);

      // Trigger auto-init
      final pendingSnap = repo.snapToRoad(lat: 21.0285, lon: 105.8542);

      // Wait until initGraphHopper has actually started
      await initStarted.future;

      // Dispose while init is in-flight
      await repo.dispose();

      // Complete init afterwards
      initCompleter.complete(true);
      await pendingSnap;
      service.initCompleter = null;
      service.initSuccess = false;

      // isEngineReady should remain false
      expect(await repo.isEngineReady(), isFalse);
    });

    test('new session initialization remains active even if previous session init finishes later', () async {
      final oldInitStarted = Completer<void>();
      final oldInitCompleter = Completer<bool>();
      final service = MockRoutingService()
        ..readyState = false
        ..initStartedCompleter = oldInitStarted
        ..initCompleter = oldInitCompleter;
      final repo = RoutingRepositoryImpl(routingService: service);

      // 1. Start old session auto-init
      final pendingOldSnap = repo.snapToRoad(lat: 21.0285, lon: 105.8542);
      await oldInitStarted.future;

      // 2. Dispose old session
      await repo.dispose();

      // 3. New session explicitly initializes successfully before old init completes
      service.initCompleter = null; // Next init completes immediately
      final initNewSuccess = await repo.initializeEngine('assets/map/new_graph.ghz');
      expect(initNewSuccess, isTrue);
      expect(await repo.isEngineReady(), isTrue);

      // 4. Old session in-flight init now completes
      oldInitCompleter.complete(true);
      await pendingOldSnap;

      // 5. Engine must remain READY in the new session, not destroyed by old session cleanup
      expect(await repo.isEngineReady(), isTrue);
    });

    test('pending stale auto-init followed by dispose and failed explicit init keeps engine inactive', () async {
      final oldInitStarted = Completer<void>();
      final oldInitCompleter = Completer<bool>();
      final service = MockRoutingService()
        ..readyState = false
        ..initStartedCompleter = oldInitStarted
        ..initCompleter = oldInitCompleter;
      final repo = RoutingRepositoryImpl(routingService: service);

      // 1. Start old session auto-init
      final pendingOldSnap = repo.snapToRoad(lat: 21.0285, lon: 105.8542);
      await oldInitStarted.future;

      // 2. Dispose old session
      await repo.dispose();

      // 3. New explicit init fails
      service.initCompleter = null;
      service.initSuccess = false;
      final failedInit = await repo.initializeEngine('assets/map/invalid_path.ghz');
      expect(failedInit, isFalse);

      // 4. Old session in-flight init now completes with true on mock
      oldInitCompleter.complete(true);
      await pendingOldSnap;

      // 5. Engine must NOT be resurrected; isEngineReady() remains false
      expect(await repo.isEngineReady(), isFalse);
    });
  });

  group('calculateAlternativeRoutes Spur & Backtracking rejection', () {
    test('rejects alternative via-point that creates backtracking / U-turn spur',
        () async {
      final mockService = MockRoutingService()..readyState = true;
      final repo = RoutingRepositoryImpl(routingService: mockService);

      // Primary route: Trục đường thẳng từ Bắc xuống Nam (lon = 105.0)
      final primaryPoints = List.generate(
        12,
        (i) => [21.0 + (i * 0.001), 105.0],
      );
      final primaryResult = RouteResult(
        isSuccess: true,
        distance: 1200.0,
        time: 180000,
        points: primaryPoints,
        instructions: const [
          RouteInstruction(
            text: 'Đi thẳng',
            streetName: 'Lý Thường Kiệt',
            distance: 1200.0,
            time: 180000,
            sign: 0,
            points: [],
          ),
        ],
      );

      // Điểm snap nằm ở hẻm cụt phía Đông (lon = 105.002)
      mockService.customSnapHandler = (lat, lon) async {
        return SnappedRoadPoint(
          isSnapped: true,
          originalLat: lat,
          originalLon: lon,
          snappedLat: lat,
          snappedLon: 105.002, // Hẻm đâm sang ngang
          streetName: 'Hẻm 123',
          distanceToRoad: 2.0,
          edgeId: 101,
          calculationTimeMs: 1,
        );
      };

      // Handler route giả lập:
      // - Chặng 1: Start -> Hẻm cụt: Đi dọc trục lon=105.0 rồi rẽ vào 105.002
      // - Chặng 2: Hẻm cụt -> End: Quay đầu xe từ 105.002 ngược ra 105.0 rồi đi tiếp xuống Nam
      mockService.customRouteHandler =
          (fromLat, fromLon, toLat, toLon, profile) async {
        if ((fromLat - 21.0).abs() < 1e-4 && (toLon - 105.002).abs() < 1e-4) {
          // Leg 1: Đến điểm hẻm cụt
          return const RouteResult(
            isSuccess: true,
            distance: 700.0,
            time: 100000,
            points: [
              [21.0, 105.0],
              [21.003, 105.0],
              [21.006, 105.0],
              [21.006, 105.001],
              [21.006, 105.002], // Đi vào hẻm
            ],
            instructions: [
              RouteInstruction(
                text: 'Bạn đã đến nơi',
                streetName: 'Hẻm 123',
                distance: 100.0,
                time: 20000,
                sign: 4,
                points: [],
              ),
            ],
          );
        } else if ((fromLon - 105.002).abs() < 1e-4) {
          // Leg 2: Bắt đầu từ hẻm cụt, quay đầu ngược lại [21.006, 105.001] -> [21.006, 105.0]
          return const RouteResult(
            isSuccess: true,
            distance: 650.0,
            time: 95000,
            points: [
              [21.006, 105.002],
              [21.006, 105.001], // Trùng ngược chiều với điểm của Leg 1!
              [21.006, 105.0],
              [21.009, 105.0],
              [21.011, 105.0],
            ],
            instructions: [
              RouteInstruction(
                text: 'Đi về hướng Tây',
                streetName: 'Hẻm 123',
                distance: 100.0,
                time: 20000,
                sign: 0,
                points: [],
              ),
            ],
          );
        }
        return primaryResult;
      };

      final routes = await repo.calculateAlternativeRoutes(
        fromLat: 21.0,
        fromLon: 105.0,
        toLat: 21.011,
        toLon: 105.0,
      );

      // Phải loại bỏ candidate có nhánh cụt quay đầu này -> Chỉ còn 1 lộ trình chính tối ưu
      expect(routes.length, 1);
      expect(routes.first.routeTitle, 'Lộ trình tối ưu');
    });

    test('accepts clean through-route alternative without backtracking',
        () async {
      final mockService = MockRoutingService()..readyState = true;
      final repo = RoutingRepositoryImpl(routingService: mockService);

      // Primary route: Đường đi dọc lon = 105.000
      final primaryPoints = List.generate(
        12,
        (i) => [21.0 + (i * 0.001), 105.0],
      );
      final primaryResult = RouteResult(
        isSuccess: true,
        distance: 1200.0,
        time: 180000,
        points: primaryPoints,
        instructions: const [
          RouteInstruction(
            text: 'Đi thẳng',
            streetName: 'Lý Thường Kiệt',
            distance: 1200.0,
            time: 180000,
            sign: 0,
            points: [],
          ),
        ],
      );

      // Điểm snap ở trục đường song song thông suốt (Đường Giải Phóng)
      mockService.customSnapHandler = (lat, lon) async {
        return SnappedRoadPoint(
          isSnapped: true,
          originalLat: lat,
          originalLon: lon,
          snappedLat: lat,
          snappedLon: 105.004,
          streetName: 'Đường Giải Phóng',
          distanceToRoad: 2.0,
          edgeId: 202,
          calculationTimeMs: 1,
        );
      };

      // Handler route giả lập: Chạy trên trục song song lon=105.004 thông suốt liên tục về phía Bắc
      mockService.customRouteHandler =
          (fromLat, fromLon, toLat, toLon, profile) async {
        if ((fromLat - 21.0).abs() < 1e-4 && (toLon - 105.004).abs() < 1e-4) {
          // Leg 1: Đi từ Start sang trục song song và chạy lên phía Bắc
          return const RouteResult(
            isSuccess: true,
            distance: 720.0,
            time: 105000,
            points: [
              [21.0, 105.0],
              [21.002, 105.004],
              [21.004, 105.004],
              [21.006, 105.004],
            ],
            instructions: [
              RouteInstruction(
                text: 'Rẽ phải vào Giải Phóng',
                streetName: 'Đường Giải Phóng',
                distance: 720.0,
                time: 105000,
                sign: 2,
                points: [],
              ),
              RouteInstruction(
                text: 'Bạn đã đến nơi',
                streetName: 'Đường Giải Phóng',
                distance: 0.0,
                time: 0,
                sign: 4,
                points: [],
              ),
            ],
          );
        } else if ((fromLon - 105.004).abs() < 1e-4) {
          // Leg 2: Tiếp tục chạy thẳng lên phía Bắc trên trục song song, không quay đầu
          return const RouteResult(
            isSuccess: true,
            distance: 680.0,
            time: 98000,
            points: [
              [21.006, 105.004],
              [21.008, 105.004],
              [21.010, 105.004],
              [21.011, 105.0],
            ],
            instructions: [
              RouteInstruction(
                text: 'Đi về hướng Bắc',
                streetName: 'Đường Giải Phóng',
                distance: 400.0,
                time: 60000,
                sign: 0,
                points: [],
              ),
              RouteInstruction(
                text: 'Rẽ trái về đích',
                streetName: 'Đích',
                distance: 280.0,
                time: 38000,
                sign: 1,
                points: [],
              ),
            ],
          );
        }
        return primaryResult;
      };

      final routes = await repo.calculateAlternativeRoutes(
        fromLat: 21.0,
        fromLon: 105.0,
        toLat: 21.011,
        toLon: 105.0,
      );

      // Phải chấp nhận lộ trình thay thế thông suốt sạch đẹp
      expect(routes.length, 2);
      expect(routes.first.routeTitle, 'Nhanh nhất');
      expect(routes[1].routeTitle, 'Qua Đường Giải Phóng');
      expect(routes[1].isAlternative, isTrue);

      // Kiểm tra instructions được dọn dẹp: không còn "Bạn đã đến nơi" ở giữa lộ trình
      final altInstructions = routes[1].instructions;
      expect(
        altInstructions.any((ins) => ins.sign == 4),
        isFalse,
      );
    });
  });
}
