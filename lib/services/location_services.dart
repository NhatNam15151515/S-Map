import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart' as loc_pkg;
import 'package:permission_handler/permission_handler.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

/// LocationService implements [ILocationService] combining:
/// 1. [Geolocator] for high-performance position streaming, permission checks, and background coordinates with Android Foreground Service.
/// 2. [loc_pkg.Location] exclusively for triggering Google Play Services' native system dialog
///    (`requestService()`), giving users a seamless 1-tap "Bật" prompt without leaving the app.
/// 3. [PermissionHandler] for managing battery optimization exemptions and notification permissions.
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
  Stream<Position> get positionStream => getPositionStream();

  @override
  Stream<Position> getPositionStream({
    LocationAccuracy accuracy = LocationAccuracy.bestForNavigation,
    int distanceFilter = 0,
    Duration? intervalDuration,
    bool enableBackground = false,
    String? notificationTitle,
    String? notificationText,
    bool enableWakeLock = true,
  }) {
    LocationSettings locationSettings;

    if (enableBackground &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        intervalDuration: intervalDuration ?? const Duration(seconds: 1),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: notificationTitle ?? 'S-Map Điều hướng',
          notificationText:
              notificationText ?? 'Đang theo dõi vị trí nền trong suốt chuyến đi...',
          enableWakeLock: enableWakeLock,
        ),
      );
    } else {
      locationSettings = LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        timeLimit: intervalDuration,
      );
    }

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  @override
  Future<Position> getCurrentPosition() => _determinePosition();
  @override
  Future<Position?> getLastKnownPosition() => Geolocator.getLastKnownPosition();

  static LocationService instance = LocationService();

  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();
  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();
  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();
  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> isBatteryOptimizationIgnored() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      return status.isGranted;
    } catch (e) {
      DLog.error('Lỗi kiểm tra battery optimization: $e');
      return false;
    }
  }

  @override
  Future<bool> requestIgnoreBatteryOptimization() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      final status = await Permission.ignoreBatteryOptimizations.request();
      return status.isGranted;
    } catch (e) {
      DLog.error('Lỗi yêu cầu ignore battery optimization: $e');
      return false;
    }
  }

  @override
  Future<bool> requestNotificationPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      final status = await Permission.notification.status;
      if (status.isGranted) return true;
      final result = await Permission.notification.request();
      return result.isGranted;
    } catch (e) {
      DLog.error('Lỗi yêu cầu notification permission: $e');
      return false;
    }
  }

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
        throw const PermissionDeniedException(
            'Location permissions are denied');
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
