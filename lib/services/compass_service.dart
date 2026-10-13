import 'dart:async';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:s_map/interfaces/interfaces.dart';

class CompassService implements ICompassService {
  CompassService._();
  static final CompassService instance = CompassService._();

  @override
  Stream<double?> get compassHeadingStream {
    final events = FlutterCompass.events;
    if (events == null) {
      return const Stream.empty();
    }
    return events.map((event) => event.heading);
  }

  @override
  Future<bool> get isCompassAvailable async {
    return FlutterCompass.events != null;
  }
}
