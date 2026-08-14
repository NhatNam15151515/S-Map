import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/cubits/map_display_cubit/map_display_cubit.dart';
import 'package:s_map/commons/cubits/map_display_cubit/map_display_state.dart';
import 'package:s_map/services/location_services.dart';

class MockSuccessLocationService extends LocationService {
  final Position mockPosition;

  MockSuccessLocationService(this.mockPosition);

  @override
  Future<Position> getCurrentPosition() async => mockPosition;
}

class MockDisabledLocationService extends LocationService {
  @override
  Future<Position> getCurrentPosition() async {
    throw const LocationServiceDisabledException();
  }
}

class MockDeniedLocationService extends LocationService {
  @override
  Future<Position> getCurrentPosition() async {
    throw const PermissionDeniedException('Location permission denied.');
  }
}

class MockDeniedForeverLocationService extends LocationService {
  @override
  Future<Position> getCurrentPosition() async {
    throw LocationPermissionDeniedForeverException('Location permission denied forever.');
  }
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
      expect(cubit.state.errorMessage, null);
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
      cubit.close();
    });

    test('locateMe handles LocationServiceDisabledException gracefully', () async {
      final mockLocation = MockDisabledLocationService();
      final cubit = MapDisplayCubit(locationService: mockLocation);

      await cubit.locateMe();

      expect(cubit.state.isFollowingUser, false);
      expect(cubit.state.currentPosition, const LatLng(10.7769, 106.7009));
      expect(cubit.state.errorMessage, isNotNull);
      cubit.close();
    });

    test('locateMe handles PermissionDeniedException gracefully', () async {
      final mockLocation = MockDeniedLocationService();
      final cubit = MapDisplayCubit(locationService: mockLocation);

      await cubit.locateMe();

      expect(cubit.state.isFollowingUser, false);
      expect(cubit.state.currentPosition, const LatLng(10.7769, 106.7009));
      expect(cubit.state.errorMessage, isNotNull);
      cubit.close();
    });

    test('locateMe handles LocationPermissionDeniedForeverException gracefully', () async {
      final mockLocation = MockDeniedForeverLocationService();
      final cubit = MapDisplayCubit(locationService: mockLocation);

      await cubit.locateMe();

      expect(cubit.state.isFollowingUser, false);
      expect(cubit.state.currentPosition, const LatLng(10.7769, 106.7009));
      expect(cubit.state.errorMessage, isNotNull);
      cubit.close();
    });

    test('onCameraMove updates center, zoom, and rotation in state', () {
      final cubit = MapDisplayCubit();
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

    test('setError updates status to error and sets errorMessage', () {
      final cubit = MapDisplayCubit();

      cubit.setError('Map style load failed');

      expect(cubit.state.status, MapDisplayStatus.error);
      expect(cubit.state.errorMessage, 'Map style load failed');
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
