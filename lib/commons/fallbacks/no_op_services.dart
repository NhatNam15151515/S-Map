import 'package:firebase_auth/firebase_auth.dart' as fb;
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
  String get nightStyleJson =>
      '{"version": 8, "name": "Dark", "sources": {}, "layers": []}';

  @override
  String getStyleJson({bool isDarkMode = false}) =>
      isDarkMode ? nightStyleJson : styleJson;

  @override
  Future<void> init() async {}
}

/// Fallback / No-Op implementation for IRoutingService
class NoOpRoutingService implements IRoutingService {
  const NoOpRoutingService();

  @override
  Future<bool> initGraphHopper(String graphPath) async => false;

  @override
  Future<RouteResult> getRoute({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    String? vehicleProfile,
  }) async =>
      const RouteResult(isSuccess: false, errorMessage: 'NoOp');

  @override
  Future<SnappedRoadPoint> snapToRoad({
    required double lat,
    required double lon,
  }) async =>
      SnappedRoadPoint.notSnapped(
        originalLat: lat,
        originalLon: lon,
        errorMessage: 'NoOp',
      );

  @override
  Future<bool> isInitialized() async => false;

  @override
  Future<bool> dispose() async => true;
}

/// Fallback / No-Op implementation for IFirebaseAuthService
class NoOpFirebaseAuthService implements IFirebaseAuthService {
  const NoOpFirebaseAuthService();

  @override
  fb.User? get currentUser => null;

  @override
  Future<User?> signInWithGoogle() async => null;

  @override
  Future<User?> signInAnonymously() async => null;

  @override
  Future<void> signOut() async {}
}

/// Fallback / No-Op implementation for ITripSyncService
class NoOpTripSyncService implements ITripSyncService {
  const NoOpTripSyncService();

  @override
  Future<void> init() async {}

  @override
  Future<void> enqueueTrip(String tripId) async {}

  @override
  Future<List<String>> getQueuedTripIds() async => const [];

  @override
  Future<void> removeQueuedTrip(String tripId) async {}

  @override
  Future<void> clearQueue() async {}

  @override
  Future<int> getQueueCount() async => 0;

  @override
  Stream<int> watchQueueCount() => const Stream.empty();
}

/// Fallback / No-Op implementation for IActiveTripService
class NoOpActiveTripService implements IActiveTripService {
  const NoOpActiveTripService();

  @override
  Future<void> init() async {}

  @override
  Future<void> saveActiveSession(ActiveTripSnapshot snapshot) async {}

  @override
  Future<ActiveTripSnapshot?> getActiveSession() async => null;

  @override
  Future<void> clearActiveSession() async {}

  @override
  Future<bool> hasActiveSession() async => false;
}

