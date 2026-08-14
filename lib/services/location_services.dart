import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationPermissionDeniedForeverException implements Exception {
  final String message;
  LocationPermissionDeniedForeverException([this.message = 'Location permissions are permanently denied.']);
  @override
  String toString() => message;
}

class LocationService {
  LocationService() {
    _init();
  }

  late Position _position;

  final Completer<bool> initCompleter = Completer();

  Position get position => _position;
  (double, double) get latLng => (_position.latitude, _position.longitude);
  Stream<Position> get positionStream => Geolocator.getPositionStream();
  Future<Position> getCurrentPosition() => _determinePosition();

  static LocationService instance = LocationService();

  Future<bool> isLocationServiceEnabled() => Geolocator.isLocationServiceEnabled();
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();
  Future<LocationPermission> requestPermission() => Geolocator.requestPermission();
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  void _init() async {
    try {
      _position = await _determinePosition();
      initCompleter.complete(true);
    } on Exception catch (_) {}
  }

  /// Determine the current position of the device.
  ///
  /// When the location services are not enabled or permissions
  /// are denied the `Future` will return an error.
  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const PermissionDeniedException('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationPermissionDeniedForeverException(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }

    return await Geolocator.getCurrentPosition();
  }
}
