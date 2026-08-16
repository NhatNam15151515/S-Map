import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/services/services.dart';


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RoutingServiceImpl service;
  late List<MethodCall> log;

  setUp(() {
    log = <MethodCall>[];
    service = RoutingServiceImpl();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(RoutingConstants.channelName),
      (MethodCall methodCall) async {
        log.add(methodCall);
        switch (methodCall.method) {
          case RoutingConstants.methodInitGraphHopper:
            final path = methodCall.arguments[RoutingConstants.argGraphPath] as String?;
            if (path == null || path.isEmpty || path.contains('invalid')) {
              return false;
            }
            if (path.contains('throw_exception')) {
              throw PlatformException(
                code: 'ROUTING_FAILED',
                message: 'Failed to init graph file',
              );
            }
            return true;

          case RoutingConstants.methodGetRoute:
            final fromLat = methodCall.arguments[RoutingConstants.argFromLat] as double?;
            if (fromLat == -999.0) {
              throw PlatformException(
                code: 'ROUTING_FAILED',
                message: 'Native routing exception occurred',
              );
            }
            if (fromLat == 0.0) {
              return {
                'isSuccess': false,
                'errorMessage': RoutingConstants.errNoRouteFound,
                'calculationTimeMs': 5,
              };
            }
            return {
              'isSuccess': true,
              'distance': 2500.0,
              'time': 300000,
              'points': [
                [21.0285, 105.8542],
                [21.0380, 105.7830],
              ],
              'bbox': [105.7830, 21.0285, 105.8542, 21.0380],
              'instructions': [
                {
                  'text': 'Đi thẳng trên Kim Mã',
                  'streetName': 'Kim Mã',
                  'distance': 1500.0,
                  'time': 180000,
                  'sign': 0,
                  'points': [
                    [21.0285, 105.8542],
                    [21.0350, 105.8200],
                  ],
                }
              ],
              'calculationTimeMs': 25,
            };

          case RoutingConstants.methodIsInitialized:
            return true;

          case RoutingConstants.methodDisposeGraphHopper:
            return true;

          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(RoutingConstants.channelName),
      null,
    );
  });

  group('RoutingServiceImpl MethodChannel Tests', () {
    test('initGraphHopper should invoke correct channel method and return boolean', () async {
      final success = await service.initGraphHopper('/valid/path/vietnam.ghz');
      expect(success, isTrue);
      expect(log.length, equals(1));
      expect(log.first.method, equals(RoutingConstants.methodInitGraphHopper));
      expect(log.first.arguments[RoutingConstants.argGraphPath], equals('/valid/path/vietnam.ghz'));

      final failure = await service.initGraphHopper('/invalid/path.ghz');
      expect(failure, isFalse);

      final exceptionHandled = await service.initGraphHopper('/throw_exception.ghz');
      expect(exceptionHandled, isFalse);
    });

    test('getRoute should parse valid route result and forward profile with deep assertions', () async {
      final result = await service.getRoute(
        fromLat: 21.0285,
        fromLon: 105.8542,
        toLat: 21.0380,
        toLon: 105.7830,
        vehicleProfile: RoutingConstants.profileMotorcycle,
      );

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.distance, equals(2500.0));
      expect(result.time, equals(300000));
      expect(result.calculationTimeMs, equals(25));
      expect(result.hasInstructions, isTrue);
      expect(result.hasPoints, isTrue);

      // Deep assert points
      expect(result.points.length, equals(2));
      expect(result.points[0], equals([21.0285, 105.8542]));
      expect(result.points[1], equals([21.0380, 105.7830]));

      // Deep assert bbox
      expect(result.bbox, equals([105.7830, 21.0285, 105.8542, 21.0380]));

      // Deep assert instructions
      expect(result.instructions.length, equals(1));
      final instruction = result.instructions.first;
      expect(instruction.text, equals('Đi thẳng trên Kim Mã'));
      expect(instruction.streetName, equals('Kim Mã'));
      expect(instruction.distance, equals(1500.0));
      expect(instruction.time, equals(180000));
      expect(instruction.sign, equals(0));
      expect(instruction.points.length, equals(2));
      expect(instruction.points[0], equals([21.0285, 105.8542]));
      expect(instruction.points[1], equals([21.0350, 105.8200]));

      expect(log.last.method, equals(RoutingConstants.methodGetRoute));
      expect(log.last.arguments[RoutingConstants.argVehicleProfile],
          equals(RoutingConstants.profileMotorcycle));
    });

    test('getRoute should use default profile when not specified', () async {
      await service.getRoute(
        fromLat: 21.0285,
        fromLon: 105.8542,
        toLat: 21.0380,
        toLon: 105.7830,
      );

      expect(log.last.arguments[RoutingConstants.argVehicleProfile],
          equals(RoutingConstants.defaultProfile));
    });

    test('getRoute should handle native failure map gracefully', () async {
      final result = await service.getRoute(
        fromLat: 0.0,
        fromLon: 105.8542,
        toLat: 21.0380,
        toLon: 105.7830,
      );

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.errorMessage, equals(RoutingConstants.errNoRouteFound));
    });

    test('getRoute should catch PlatformException and return Failure RouteResult', () async {
      final result = await service.getRoute(
        fromLat: -999.0,
        fromLon: 105.8542,
        toLat: 21.0380,
        toLon: 105.7830,
      );

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.errorMessage, contains('Native routing exception occurred'));
    });

    test('isInitialized and dispose should invoke platform channel correctly', () async {
      final isInit = await service.isInitialized();
      expect(isInit, isTrue);
      expect(log.last.method, equals(RoutingConstants.methodIsInitialized));

      final disposed = await service.dispose();
      expect(disposed, isTrue);
      expect(log.last.method, equals(RoutingConstants.methodDisposeGraphHopper));
    });
  });
}
