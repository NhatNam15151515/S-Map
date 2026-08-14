import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/cubits/map_display_cubit/map_display_cubit.dart';
import 'package:s_map/commons/cubits/map_display_cubit/map_display_state.dart';
import 'package:s_map/constants/map_constants.dart';
import 'package:s_map/interfaces/i_location_service.dart';
import 'package:s_map/services/location_services.dart';

class MockSuccessLocationService implements ILocationService {
  final Position mockPosition;
  final Position? mockLastKnown;

  MockSuccessLocationService(this.mockPosition, {this.mockLastKnown});

  @override
  Position get position => mockPosition;

  @override
  (double, double) get latLng => (mockPosition.latitude, mockPosition.longitude);

  @override
  Stream<Position> get positionStream => Stream.value(mockPosition);

  @override
  Future<Position> getCurrentPosition() async => mockPosition;

  @override
  Future<Position?> getLastKnownPosition() async => mockLastKnown ?? mockPosition;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async => LocationPermission.always;

  @override
  Future<LocationPermission> requestPermission() async => LocationPermission.always;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<bool> openAppSettings() async => true;
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
  Future<LocationPermission> checkPermission() async => LocationPermission.denied;

  @override
  Future<LocationPermission> requestPermission() async => LocationPermission.denied;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<bool> openAppSettings() async => true;
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
  Future<LocationPermission> checkPermission() async => LocationPermission.denied;

  @override
  Future<LocationPermission> requestPermission() async => LocationPermission.denied;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<bool> openAppSettings() async => true;
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
    throw LocationPermissionDeniedForeverException('Location permission denied forever.');
  }

  @override
  Future<Position?> getLastKnownPosition() async => null;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async => LocationPermission.deniedForever;

  @override
  Future<LocationPermission> requestPermission() async => LocationPermission.deniedForever;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<bool> openAppSettings() async => true;
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
    test('Initial state is correct', () {
      final cubit = MapDisplayCubit();
      expect(cubit.state.status, MapDisplayStatus.initial);
      expect(cubit.state.isFollowingUser, false);
      expect(cubit.state.zoom, 14.0);
      expect(cubit.state.rotation, 0.0);
      expect(cubit.state.currentPosition, null);
      expect(cubit.state.center, null);
      expect(cubit.state.errorMessageKey, null);
      cubit.close();
    });

    test('locateMe success updates position, center, and sets isFollowingUser to true', () async {
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

    test('locateMe utilizes cached position for instant flyback when available', () async {
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

    test('locateMe handles LocationServiceDisabledException gracefully', () async {
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

    test('locateMe handles LocationPermissionDeniedForeverException gracefully', () async {
      final mockLocation = MockDeniedForeverLocationService();
      final cubit = MapDisplayCubit(locationService: mockLocation);

      await cubit.locateMe();

      expect(cubit.state.isFollowingUser, false);
      expect(cubit.state.currentPosition, MapConstants.defaultLocation);
      expect(cubit.state.errorMessageKey, 'map.location_permission_denied_forever');
      cubit.close();
    });

    test('onCameraMove updates center, zoom, and rotation in state and clears error', () {
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

    test('onCameraTrackingDismissed sets isFollowingUser to false', () {
      final cubit = MapDisplayCubit();
      cubit.emit(cubit.state.copyWith(isFollowingUser: true));
      expect(cubit.state.isFollowingUser, true);

      cubit.onCameraTrackingDismissed();

      expect(cubit.state.isFollowingUser, false);
      cubit.close();
    });

    test('setError updates status to error and sets errorMessageKey', () {
      final cubit = MapDisplayCubit();

      cubit.setError('map.error_load');

      expect(cubit.state.status, MapDisplayStatus.error);
      expect(cubit.state.errorMessageKey, 'map.error_load');
      cubit.close();
    });

    test('emit guard prevents state emission after cubit is closed', () {
      final cubit = MapDisplayCubit();
      cubit.close();

      // Should not throw Bad state: Cannot emit new states after calling close
      cubit.onCameraTrackingDismissed();
      expect(cubit.isClosed, true);
    });
  });
}
