import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/repos/repos.dart';


class MockRoutingService implements IRoutingService {
  bool initCalled = false;
  String? lastGraphPath;
  bool routeCalled = false;
  String? lastProfile;
  bool disposeCalled = false;
  bool readyState = false;

  final RouteResult mockResult;

  MockRoutingService({RouteResult? customResult})
      : mockResult = customResult ??
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
    lastGraphPath = graphPath;
    readyState = true;
    return true;
  }

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
    // Simulate real-world invocation delay
    await Future.delayed(const Duration(milliseconds: 2));
    return mockResult;
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
    mockService = MockRoutingService();
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
      expect(await repository.isEngineReady(), isFalse);
      await repository.initializeEngine('/path.ghz');
      expect(await repository.isEngineReady(), isTrue);

      final disposed = await repository.dispose();
      expect(disposed, isTrue);
      expect(mockService.disposeCalled, isTrue);
      expect(await repository.isEngineReady(), isFalse);
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
  });
}
