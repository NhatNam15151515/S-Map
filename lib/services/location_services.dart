import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart' as loc_pkg;
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/i_location_service.dart';

class LocationPermissionDeniedForeverException implements Exception {
  final String message;
  LocationPermissionDeniedForeverException([this.message = 'Location permissions are permanently denied.']);
  @override
  String toString() => message;
}

class LocationService implements ILocationService {
  final loc_pkg.Location _nativeLocation;

  LocationService({loc_pkg.Location? nativeLocation})
      : _nativeLocation = nativeLocation ?? loc_pkg.Location() {
    _init();
  }

  late Position _position;

  final Completer<bool> initCompleter = Completer();

  @override
  Position get position => _position;
  @override
  (double, double) get latLng => (_position.latitude, _position.longitude);
  @override
  Stream<Position> get positionStream => Geolocator.getPositionStream();
  @override
  Future<Position> getCurrentPosition() => _determinePosition();

  static LocationService instance = LocationService();

  @override
  Future<bool> isLocationServiceEnabled() => Geolocator.isLocationServiceEnabled();
  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();
  @override
  Future<LocationPermission> requestPermission() => Geolocator.requestPermission();
  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  void _init() async {
    try {
      _position = await _determinePosition();
      initCompleter.complete(true);
    } on Exception catch (_) {}
  }

  /// Determine the current position of the device.
  ///
  /// When location services are disabled, it automatically requests the OS
  /// to show Google Play Services' native "Turn On Location" resolution prompt.
  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      try {
        serviceEnabled = await _nativeLocation.requestService();
      } catch (e) {
        DLog.error('Lỗi yêu cầu bật dịch vụ vị trí hệ thống: $e');
      }

      if (!serviceEnabled) {
        throw const LocationServiceDisabledException();
      }
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

