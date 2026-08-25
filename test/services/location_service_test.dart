import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:s_map/commons/fallbacks/fallbacks.dart';
import 'package:s_map/services/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocationService / Fallbacks Tests', () {
    test('NoOpLocationService methods return safe defaults', () async {
      const fallback = NoOpLocationService();

      expect(fallback.position.latitude, equals(0.0));
      expect(fallback.position.longitude, equals(0.0));
      expect(fallback.latLng, equals((0.0, 0.0)));

      expect(await fallback.getCurrentPosition(), isNotNull);
      expect(await fallback.getLastKnownPosition(), isNull);
      expect(await fallback.isLocationServiceEnabled(), isFalse);
      expect(await fallback.checkPermission(), equals(LocationPermission.denied));
      expect(await fallback.requestPermission(), equals(LocationPermission.denied));
      expect(await fallback.openLocationSettings(), isFalse);
      expect(await fallback.openAppSettings(), isFalse);

      expect(await fallback.isBatteryOptimizationIgnored(), isTrue);
      expect(await fallback.requestIgnoreBatteryOptimization(), isTrue);
      expect(await fallback.requestNotificationPermission(), isTrue);

      final stream = fallback.getPositionStream(
        enableBackground: true,
        notificationTitle: 'Test Title',
        notificationText: 'Test Text',
      );
      expect(stream, isNotNull);
    });

    test('LocationService instance exists and getPositionStream creates valid stream', () {
      final service = LocationService.instance;
      expect(service, isNotNull);

      final stream = service.getPositionStream(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        enableBackground: false,
      );
      expect(stream, isNotNull);
    });
  });
}
