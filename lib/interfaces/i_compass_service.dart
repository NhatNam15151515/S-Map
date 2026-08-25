import 'dart:async';

/// Abstract interface for device compass sensor
abstract class ICompassService {
  /// Stream emitting device compass heading (0° to 360°, North = 0° / 360°)
  Stream<double?> get compassHeadingStream;

  /// Check whether device has compass sensor available
  Future<bool> get isCompassAvailable;
}
