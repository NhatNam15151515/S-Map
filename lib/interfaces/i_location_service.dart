import 'dart:async';
import 'package:geolocator/geolocator.dart';

abstract class ILocationService {
  Position get position;
  (double, double) get latLng;
  Stream<Position> get positionStream;

  Stream<Position> getPositionStream({
    LocationAccuracy accuracy = LocationAccuracy.bestForNavigation,
    int distanceFilter = 0,
    Duration? intervalDuration,
    bool enableBackground = false,
    String? notificationTitle,
    String? notificationText,
    bool enableWakeLock = true,
  });

  Future<Position> getCurrentPosition();
  Future<Position?> getLastKnownPosition();
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<bool> openLocationSettings();
  Future<bool> openAppSettings();

  /// Kiểm tra xem ứng dụng đã được miễn trừ tối ưu hóa pin (Battery Optimization) chưa
  Future<bool> isBatteryOptimizationIgnored();

  /// Yêu cầu hệ điều hành miễn trừ tối ưu hóa pin cho ứng dụng
  Future<bool> requestIgnoreBatteryOptimization();

  /// Yêu cầu quyền thông báo (bắt buộc từ Android 13+ để hiển thị Foreground Notification)
  Future<bool> requestNotificationPermission();
}
