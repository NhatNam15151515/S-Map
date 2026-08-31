import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

class MockSuccessLocationService implements ILocationService {
  final Position mockPosition;
  final Position? mockLastKnown;

  MockSuccessLocationService(this.mockPosition, {this.mockLastKnown});

  @override
  Position get position => mockPosition;

  @override
  (double, double) get latLng =>
      (mockPosition.latitude, mockPosition.longitude);

  @override
  Stream<Position> get positionStream => Stream.value(mockPosition);

  @override
  Future<Position> getCurrentPosition() async => mockPosition;

  @override
  Future<Position?> getLastKnownPosition() async =>
      mockLastKnown ?? mockPosition;

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

class MockDisabledLocationService implements ILocationService {
  @override
  Position get position => throw UnimplementedError();

  @override
  (double, double) get latLng => throw UnimplementedError();

  @override
  Stream<Position> get positionStream => const Stream.empty();

  @override
  Future<Position> getCurrentPosition() async {
    throw const LocationServiceDisabledException();
  }

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
      const Stream.empty();

  @override
  Future<bool> isBatteryOptimizationIgnored() async => false;

  @override
  Future<bool> requestIgnoreBatteryOptimization() async => false;

  @override
  Future<bool> requestNotificationPermission() async => false;
}

class MockDeniedLocationService implements ILocationService {
  @override
  Position get position => throw UnimplementedError();

  @override
  (double, double) get latLng => throw UnimplementedError();

  @override
  Stream<Position> get positionStream => const Stream.empty();

  @override
  Future<Position> getCurrentPosition() async {
    throw const PermissionDeniedException('Location permission denied.');
  }

  @override
  Future<Position?> getLastKnownPosition() async => null;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.denied;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.denied;

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
      const Stream.empty();

  @override
  Future<bool> isBatteryOptimizationIgnored() async => false;

  @override
  Future<bool> requestIgnoreBatteryOptimization() async => false;

  @override
  Future<bool> requestNotificationPermission() async => false;
}

class MockDeniedForeverLocationService implements ILocationService {
  @override
  Position get position => throw UnimplementedError();

  @override
  (double, double) get latLng => throw UnimplementedError();

  @override
  Stream<Position> get positionStream => const Stream.empty();

  @override
  Future<Position> getCurrentPosition() async {
    throw LocationPermissionDeniedForeverException(
        'Location permission denied forever.');
  }

  @override
  Future<Position?> getLastKnownPosition() async => null;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.deniedForever;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.deniedForever;

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
      const Stream.empty();

  @override
  Future<bool> isBatteryOptimizationIgnored() async => false;

  @override
  Future<bool> requestIgnoreBatteryOptimization() async => false;

  @override
  Future<bool> requestNotificationPermission() async => false;
}

class MockCompassService implements ICompassService {
  final StreamController<double?> _controller =
      StreamController<double?>.broadcast();
  bool available = true;

  void emitHeading(double? heading) {
    if (!_controller.isClosed) {
      _controller.add(heading);
    }
  }

  @override
  Stream<double?> get compassHeadingStream => _controller.stream;

  @override
  Future<bool> get isCompassAvailable async => available;

  void dispose() {
    _controller.close();
  }
}

class MockMapStyleService implements IMapStyleService {
  final String mockStyle;
  final String mockNightStyle;
  MockMapStyleService(this.mockStyle,
      {this.mockNightStyle = '{"version": 8, "name": "Night"}'});

  @override
  String get styleJson => mockStyle;

  @override
  String get nightStyleJson => mockNightStyle;

  @override
  String getStyleJson({bool isDarkMode = false}) =>
      isDarkMode ? nightStyleJson : styleJson;

  @override
  Future<void> init() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final samplePosition = Position(
    longitude: 106.660172,
    latitude: 10.762622,
    timestamp: DateTime.now(),
    accuracy: 10.0,
    altitude: 10.0,
    altitudeAccuracy: 1.0,
    heading: 0.0,
    headingAccuracy: 1.0,
    speed: 0.0,
    speedAccuracy: 1.0,
  );

  group('MapDisplayCubit Tests', () {
    test('Initial state is correct with default and injected map style', () {
      final mockStyleService =
          MockMapStyleService('{"version": 8, "sources": {}}');
      final cubit = MapDisplayCubit(mapStyleService: mockStyleService);
      expect(cubit.state.status, MapDisplayStatus.initial);
      expect(cubit.state.styleString, '{"version": 8, "sources": {}}');
      expect(cubit.state.isFollowingUser, false);
      expect(cubit.state.zoom, 14.0);
      expect(cubit.state.rotation, 0.0);
      expect(cubit.state.orientationMode, MapOrientationMode.northUp);
      expect(cubit.state.compassHeading, null);
      expect(cubit.state.currentPosition, null);
      expect(cubit.state.center, null);
      expect(cubit.state.errorMessageKey, null);
      cubit.close();
    });

    test(
        'locateMe success updates position, center, and sets isFollowingUser to true',
        () async {
      final mockLocation = MockSuccessLocationService(samplePosition);
      final cubit = MapDisplayCubit(locationService: mockLocation);

      await cubit.locateMe();

      expect(cubit.state.status, MapDisplayStatus.ready);
      expect(cubit.state.currentPosition, const LatLng(10.762622, 106.660172));
      expect(cubit.state.center, const LatLng(10.762622, 106.660172));
      expect(cubit.state.isFollowingUser, true);
      expect(cubit.state.errorMessageKey, null);
      cubit.close();
    });

    test('locateMe utilizes cached position for instant flyback when available',
        () async {
      final mockLocation = MockSuccessLocationService(samplePosition);
      final cubit = MapDisplayCubit(locationService: mockLocation);

      // Pre-set existing location in state (e.g. user panned away)
      const existingPos = LatLng(10.762622, 106.660172);
      cubit.emit(cubit.state.copyWith(
        currentPosition: existingPos,
        center: const LatLng(21.0285, 105.8542), // Hanoi
        isFollowingUser: false,
      ));

      expect(cubit.state.center, const LatLng(21.0285, 105.8542));
      expect(cubit.state.isFollowingUser, false);

      await cubit.locateMe();

      expect(cubit.state.center, existingPos);
      expect(cubit.state.isFollowingUser, true);
      cubit.close();
    });

    test('locateMe handles LocationServiceDisabledException gracefully',
        () async {
      final mockLocation = MockDisabledLocationService();
      final cubit = MapDisplayCubit(locationService: mockLocation);

      await cubit.locateMe();

      expect(cubit.state.isFollowingUser, false);
      expect(cubit.state.currentPosition, MapConstants.defaultLocation);
      expect(cubit.state.errorMessageKey, 'map.location_service_disabled');
      cubit.close();
    });

    test('locateMe handles PermissionDeniedException gracefully', () async {
      final mockLocation = MockDeniedLocationService();
      final cubit = MapDisplayCubit(locationService: mockLocation);

      await cubit.locateMe();

      expect(cubit.state.isFollowingUser, false);
      expect(cubit.state.currentPosition, MapConstants.defaultLocation);
      expect(cubit.state.errorMessageKey, 'map.location_permission_denied');
      cubit.close();
    });

    test('locateMe handles LocationPermissionDeniedForeverException gracefully',
        () async {
      final mockLocation = MockDeniedForeverLocationService();
      final cubit = MapDisplayCubit(locationService: mockLocation);

      await cubit.locateMe();

      expect(cubit.state.isFollowingUser, false);
      expect(cubit.state.currentPosition, MapConstants.defaultLocation);
      expect(cubit.state.errorMessageKey,
          'map.location_permission_denied_forever');
      cubit.close();
    });

    test(
        'onCameraMove updates center, zoom, and rotation in state and clears error',
        () {
      final cubit = MapDisplayCubit();
      cubit.setError('map.error_load');
      expect(cubit.state.errorMessageKey, 'map.error_load');

      const newTarget = LatLng(21.0285, 105.8542);
      const position = CameraPosition(
        target: newTarget,
        zoom: 16.5,
        bearing: 45.0,
      );

      cubit.onCameraMove(position);

      expect(cubit.state.center, newTarget);
      expect(cubit.state.zoom, 16.5);
      expect(cubit.state.rotation, 45.0);
      expect(cubit.state.errorMessageKey, null);
      cubit.close();
    });

    test(
        'onCameraTrackingDismissed sets isFollowingUser to false and resets to northUp',
        () {
      final cubit = MapDisplayCubit();
      cubit.emit(cubit.state.copyWith(
        isFollowingUser: true,
        orientationMode: MapOrientationMode.headingUp,
      ));
      expect(cubit.state.isFollowingUser, true);
      expect(cubit.state.orientationMode, MapOrientationMode.headingUp);

      cubit.onCameraTrackingDismissed();

      expect(cubit.state.isFollowingUser, false);
      expect(cubit.state.orientationMode, MapOrientationMode.northUp);
      cubit.close();
    });

    test('setError updates status to error and sets errorMessageKey', () {
      final cubit = MapDisplayCubit();

      cubit.setError('map.error_load');

      expect(cubit.state.status, MapDisplayStatus.error);
      expect(cubit.state.errorMessageKey, 'map.error_load');
      cubit.close();
    });

    test('emit guard prevents state emission after cubit is closed', () async {
      final cubit = MapDisplayCubit();
      await cubit.close();

      // Should not throw Bad state: Cannot emit new states after calling close
      cubit.onCameraTrackingDismissed();
      expect(cubit.isClosed, true);
    });

    // ── HEADING-UP & COMPASS TESTS ─────────────────────────────────────
    test(
        'toggleOrientationMode switches from northUp to headingUp and back to northUp',
        () async {
      final mockCompass = MockCompassService();
      final cubit = MapDisplayCubit(compassService: mockCompass);

      expect(cubit.state.orientationMode, MapOrientationMode.northUp);

      await cubit.toggleOrientationMode();
      expect(cubit.state.orientationMode, MapOrientationMode.headingUp);
      expect(cubit.state.isFollowingUser, true);

      await cubit.toggleOrientationMode();
      expect(cubit.state.orientationMode, MapOrientationMode.northUp);
      expect(cubit.state.rotation, 0.0);

      cubit.close();
      mockCompass.dispose();
    });

    test(
        'setHeadingUp starts listening to compass stream and updates rotation with anti-jitter filter',
        () async {
      final mockCompass = MockCompassService();
      final cubit = MapDisplayCubit(compassService: mockCompass);

      await cubit.setHeadingUp();
      expect(cubit.state.orientationMode, MapOrientationMode.headingUp);

      // Emit initial heading (45°)
      mockCompass.emitHeading(45.0);
      await pumpEventQueue();

      expect(cubit.state.compassHeading, 45.0);
      expect(cubit.state.rotation, 45.0);

      // Emit small jitter delta (< 1.5°) -> should be ignored
      mockCompass.emitHeading(45.8);
      await pumpEventQueue();

      expect(cubit.state.compassHeading, 45.0);
      expect(cubit.state.rotation, 45.0);

      // Emit significant heading change (>= 1.5°) -> should update
      mockCompass.emitHeading(90.0);
      await pumpEventQueue();

      expect(cubit.state.compassHeading, 90.0);
      expect(cubit.state.rotation, 90.0);

      // Emit null heading -> should be ignored safely
      mockCompass.emitHeading(null);
      await pumpEventQueue();

      expect(cubit.state.compassHeading, 90.0);
      expect(cubit.state.rotation, 90.0);

      cubit.close();
      mockCompass.dispose();
    });

    test('setNorthUp stops compass listening and resets rotation to 0',
        () async {
      final mockCompass = MockCompassService();
      final cubit = MapDisplayCubit(compassService: mockCompass);

      await cubit.setHeadingUp();
      mockCompass.emitHeading(120.0);
      await pumpEventQueue();

      expect(cubit.state.rotation, 120.0);

      await cubit.setNorthUp();
      expect(cubit.state.orientationMode, MapOrientationMode.northUp);
      expect(cubit.state.rotation, 0.0);

      // Compass emission after setNorthUp should not update rotation
      mockCompass.emitHeading(180.0);
      await pumpEventQueue();

      expect(cubit.state.rotation, 0.0);

      cubit.close();
      mockCompass.dispose();
    });

    test(
        'selectPoi updates selectedPoi and center without overwriting GPS currentPosition',
        () {
      final cubit = MapDisplayCubit();
      const gpsPosition = LatLng(10.762622, 106.660172);
      cubit.emit(cubit.state.copyWith(currentPosition: gpsPosition));
      const poi = PoiModel(
        name: 'Hồ Hoàn Kiếm',
        nameAscii: 'Ho Hoan Kiem',
        lat: 21.0285,
        lon: 105.8542,
        category: 'tourism',
      );

      cubit.selectPoi(poi);

      expect(cubit.state.selectedPoi, equals(poi));
      expect(cubit.state.center, equals(const LatLng(21.0285, 105.8542)));
      expect(cubit.state.currentPosition, equals(gpsPosition));
      expect(cubit.state.isFollowingUser, isFalse);
      expect(cubit.state.cameraAction?.type,
          equals(MapCameraActionType.animateToPosition));
      expect(cubit.state.cameraAction?.target,
          equals(const LatLng(21.0285, 105.8542)));
      expect(cubit.state.cameraAction?.zoom, equals(16.0));

      cubit.clearSelectedPoi();
      expect(cubit.state.selectedPoi, isNull);

      cubit.close();
    });

    test('updateMapTheme and toggleNightMode switch day and night map styles',
        () {
      final mockStyleService = MockMapStyleService(
        '{"version": 8, "name": "Day"}',
        mockNightStyle: '{"version": 8, "name": "Night"}',
      );
      final cubit = MapDisplayCubit(mapStyleService: mockStyleService);

      expect(cubit.state.styleString, equals('{"version": 8, "name": "Day"}'));
      expect(cubit.state.isNightMode, isFalse);

      cubit.updateMapTheme(isDarkMode: true);
      expect(
          cubit.state.styleString, equals('{"version": 8, "name": "Night"}'));
      expect(cubit.state.isNightMode, isTrue);

      cubit.updateMapTheme(isDarkMode: false);
      expect(cubit.state.styleString, equals('{"version": 8, "name": "Day"}'));
      expect(cubit.state.isNightMode, isFalse);

      cubit.toggleNightMode();
      expect(
          cubit.state.styleString, equals('{"version": 8, "name": "Night"}'));
      expect(cubit.state.isNightMode, isTrue);

      cubit.close();
    });
    test(
        '[MAP-08] onCameraMove does NOT emit duplicate state when camera position unchanged',
        () {
      final cubit = MapDisplayCubit();
      const target = LatLng(10.762, 106.660);
      const position = CameraPosition(target: target, zoom: 14.0, bearing: 0.0);

      cubit.onCameraMove(position);
      final stateAfterFirst = cubit.state;

      // Track emissions
      var emitCount = 0;
      cubit.stream.listen((_) => emitCount++);

      // Same position again — should NOT emit
      cubit.onCameraMove(position);
      expect(emitCount, 0,
          reason: 'onCameraMove should not emit duplicate state');
      expect(cubit.state, stateAfterFirst);

      cubit.close();
    });

    test('[MAP-10] zoomIn clamps at MapConstants.maxZoom and never exceeds',
        () {
      final cubit = MapDisplayCubit();
      cubit.emit(cubit.state.copyWith(zoom: MapConstants.maxZoom));

      cubit.zoomIn();

      expect(cubit.state.zoom, equals(MapConstants.maxZoom));
      expect(cubit.state.cameraAction?.type, MapCameraActionType.zoomIn);
      cubit.close();
    });

    test('[MAP-11] zoomOut clamps at MapConstants.minZoom and never goes below',
        () {
      final cubit = MapDisplayCubit();
      cubit.emit(cubit.state.copyWith(zoom: MapConstants.minZoom));

      cubit.zoomOut();

      expect(cubit.state.zoom, equals(MapConstants.minZoom));
      expect(cubit.state.cameraAction?.type, MapCameraActionType.zoomOut);
      cubit.close();
    });

    test(
        '[MAP-13] updateMapTheme does NOT emit when style and mode are unchanged',
        () {
      final mockStyleService = MockMapStyleService(
        '{"version": 8, "name": "Day"}',
        mockNightStyle: '{"version": 8, "name": "Night"}',
      );
      final cubit = MapDisplayCubit(mapStyleService: mockStyleService);

      // Set to night mode first
      cubit.updateMapTheme(isDarkMode: true);
      expect(cubit.state.isNightMode, isTrue);
      final stateAfterNight = cubit.state;

      // Track emissions
      var emitCount = 0;
      cubit.stream.listen((_) => emitCount++);

      // Same mode again — should NOT emit
      cubit.updateMapTheme(isDarkMode: true);
      expect(emitCount, 0,
          reason: 'updateMapTheme should not emit if style unchanged');
      expect(cubit.state, stateAfterNight);

      cubit.close();
    });

    test('[MAP-04] Instant Flyback uses lastKnownPosition before fresh GPS fix',
        () async {
      final lastKnownPos = Position(
        longitude: 106.1,
        latitude: 10.1,
        timestamp: DateTime.now(),
        accuracy: 50.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
      final freshPos = Position(
        longitude: 106.2,
        latitude: 10.2,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

      final mockLocation = MockSuccessLocationService(
        freshPos,
        mockLastKnown: lastKnownPos,
      );
      final cubit = MapDisplayCubit(locationService: mockLocation);

      // No cached position yet, so locateMe should use lastKnown first
      final states = <MapDisplayState>[];
      cubit.stream.listen(states.add);

      await cubit.locateMe();

      // Final state should be at freshPos
      expect(cubit.state.currentPosition, const LatLng(10.2, 106.2));
      expect(cubit.state.isFollowingUser, true);

      cubit.close();
    });
  });
}
