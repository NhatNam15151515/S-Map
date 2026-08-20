import 'package:geolocator/geolocator.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

/// Fallback / No-Op implementation for ILocationService in detached/testing environments
class NoOpLocationService implements ILocationService {
  const NoOpLocationService();

  @override
  Position get position => Position(
        longitude: 0.0,
        latitude: 0.0,
        timestamp: DateTime.fromMillisecondsSinceEpoch(0),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

  @override
  (double, double) get latLng => (0.0, 0.0);

  @override
  Stream<Position> get positionStream => const Stream.empty();

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
  Future<Position> getCurrentPosition() async => position;

  @override
  Future<Position?> getLastKnownPosition() async => null;

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
  Future<bool> isBatteryOptimizationIgnored() async => true;

  @override
  Future<bool> requestIgnoreBatteryOptimization() async => true;

  @override
  Future<bool> requestNotificationPermission() async => true;
}

/// Fallback / No-Op implementation for IDeviceInfoService
class NoOpDeviceInfoService implements IDeviceInfoService {
  const NoOpDeviceInfoService();

  @override
  Future<DeviceOemType> getDeviceOemType() async =>
      DeviceOemType.genericAndroid;

  @override
  Future<String> getManufacturer() async => 'MockManufacturer';

  @override
  Future<String> getModel() async => 'MockModel';

  @override
  Future<int> getAndroidSdkInt() async => 34;

  @override
  Future<bool> isAndroid() async => true;

  @override
  Future<bool> isIOS() async => false;
}

/// Fallback / No-Op implementation for ICompassService
class NoOpCompassService implements ICompassService {
  const NoOpCompassService();

  @override
  Stream<double?> get compassHeadingStream => const Stream.empty();

  @override
  Future<bool> get isCompassAvailable async => false;
}

/// Fallback / No-Op implementation for IMapStyleService
class NoOpMapStyleService implements IMapStyleService {
  const NoOpMapStyleService();

  @override
  String get styleJson => '{"version": 8, "sources": {}, "layers": []}';

  @override
  Future<void> init() async {}
}
