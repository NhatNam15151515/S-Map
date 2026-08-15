import 'package:geolocator/geolocator.dart';
import 'package:s_map/interfaces/interfaces.dart';

/// Fallback / No-Op implementation for ILocationService in detached/testing environments
class NoOpLocationService implements ILocationService {
  @override
  Position get position => Position(
        longitude: 106.660172,
        latitude: 10.762622,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

  @override
  (double, double) get latLng => (10.762622, 106.660172);

  @override
  Stream<Position> get positionStream => const Stream.empty();

  @override
  Future<Position> getCurrentPosition() async => position;

  @override
  Future<Position?> getLastKnownPosition() async => null;

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
}

/// Fallback / No-Op implementation for ICompassService
class NoOpCompassService implements ICompassService {
  @override
  Stream<double?> get compassHeadingStream => const Stream.empty();

  @override
  Future<bool> get isCompassAvailable async => false;
}

/// Fallback / No-Op implementation for IMapStyleService
class NoOpMapStyleService implements IMapStyleService {
  @override
  String get styleJson => '{"version": 8, "sources": {}, "layers": []}';

  @override
  Future<void> init() async {}
}
