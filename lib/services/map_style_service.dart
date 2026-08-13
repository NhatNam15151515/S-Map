import 'package:flutter/services.dart';

class MapStyleService {
  late String _styleJson;
  String get styleJson => _styleJson;

  static MapStyleService instance = MapStyleService();

  Future<void> init() async {
    _styleJson = await rootBundle.loadString('assets/map/style.json');
  }
}
