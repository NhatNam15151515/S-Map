abstract class IMapStyleService {
  String get styleJson;
  String get nightStyleJson;
  String getStyleJson({bool isDarkMode = false});
  Future<void> init();
}
