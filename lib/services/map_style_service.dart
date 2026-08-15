import 'package:flutter/services.dart';
import 'package:s_map/interfaces/interfaces.dart';

class MapStyleService implements IMapStyleService {
  late String _styleJson;
  @override
  String get styleJson => _styleJson;

  static MapStyleService instance = MapStyleService();

  @override
  Future<void> init() async {
    _styleJson = await rootBundle.loadString('assets/map/style.json');
  }
}
