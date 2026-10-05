import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart' as loc_pkg;
import 'package:permission_handler/permission_handler.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

/// LocationService implements [ILocationService] combining:
/// 1. [Geolocator] for position streaming & permission checks.
/// 2. [loc_pkg.Location] exclusively for the native "Bật định vị" dialog
///    (`requestService()`) — hoạt động offline.
/// 3. [PermissionHandler] for battery optimization & notification permissions.
///
/// Khi lấy toạ độ, dùng `forceLocationManager: true` để bypass
/// FusedLocationProvider (GMS) — GPS hardware thuần, không cần internet.
class LocationService implements ILocationService {
  final loc_pkg.Location _nativeLocation;

  LocationService({loc_pkg.Location? nativeLocation})
      : _nativeLocation = nativeLocation ?? loc_pkg.Location();

  Position _position = Position(
    longitude: 0,
    latitude: 0,
    timestamp: DateTime.fromMillisecondsSinceEpoch(0),
    accuracy: 0,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

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
      );
    }

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  @override
  Future<Position> getCurrentPosition() async {
    // Location is intentionally lazy. Asking for it in the service
    // constructor opened the GPS/permission prompt before the user tapped a
    // location action and made the map flash during startup.
    final currentPosition = await _determinePosition();
    _position = currentPosition;
    if (!initCompleter.isCompleted) initCompleter.complete(true);
    return currentPosition;
  }
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

  /// Determine the current position of the device.
  ///
  /// Khi GPS tắt, hiện dialog hệ thống "Bật định vị" qua GMS (`requestService`).
  /// Khi lấy toạ độ, dùng Android LocationManager thuần (không cần internet).
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
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      // Khi offline trong phòng kín không bắt được sóng vệ tinh, lấy vị trí
      // ghi nhận gần nhất từ phần cứng thiết bị để người dùng không bị treo.
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        return lastKnown;
      }
      rethrow;
    }
  }
}
