import 'package:flutter/material.dart';

/// Pure static helper for motorcycle route formatting and UI mapping
class RouteFormatHelper {
  RouteFormatHelper._();

  static const IconData motorcycleIcon = Icons.two_wheeler_rounded;

  /// Định dạng khoảng cách theo mét hoặc kilômét
  static String formatDistance(double distanceMeters) {
    if (distanceMeters < 0) return '0 m';
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    final km = distanceMeters / 1000;
    return '${km.toStringAsFixed(1)} km';
  }

  /// Định dạng thời gian di chuyển từ mili-giây sang giờ và phút
  static String formatDuration(int timeMillis) {
    if (timeMillis <= 0) return '< 1 phút';

    final totalMinutes = (timeMillis / 60000).round();
    if (totalMinutes < 1) {
      return '< 1 phút';
    }
    if (totalMinutes < 60) {
      return '$totalMinutes phút';
    }

    final hours = totalMinutes ~/ 60;
    final remainingMinutes = totalMinutes % 60;
    if (remainingMinutes == 0) {
      return '$hours giờ';
    }
    return '$hours giờ $remainingMinutes phút';
  }
}
