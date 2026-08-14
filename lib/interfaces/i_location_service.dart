import 'dart:async';
import 'package:geolocator/geolocator.dart';

abstract class ILocationService {
  Position get position;
  (double, double) get latLng;
  Stream<Position> get positionStream;
  Future<Position> getCurrentPosition();
  Future<Position?> getLastKnownPosition();
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<bool> openLocationSettings();
  Future<bool> openAppSettings();
}
