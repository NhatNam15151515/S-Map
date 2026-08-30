import 'package:flutter/services.dart';
import 'package:s_map/interfaces/interfaces.dart';

class MapStyleService implements IMapStyleService {
  String? _styleJson;
  String? _nightStyleJson;

  @override
  String get styleJson => _styleJson ?? '';

  @override
  String get nightStyleJson => _nightStyleJson ?? '';

  @override
  String getStyleJson({bool isDarkMode = false}) {
    if (isDarkMode && _nightStyleJson != null && _nightStyleJson!.isNotEmpty) {
      return _nightStyleJson!;
    }
    return styleJson;
  }

  static MapStyleService instance = MapStyleService();

  @override
  Future<void> init() async {
    try {
      _styleJson = await rootBundle.loadString('assets/map/style.json');
    } catch (_) {
      _styleJson = '';
    }

    try {
      _nightStyleJson =
          await rootBundle.loadString('assets/map/night_style.json');
    } catch (_) {
      _nightStyleJson = '';
    }
  }
}
