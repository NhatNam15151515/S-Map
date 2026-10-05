abstract class IMapStyleService {
  String get styleJson;
  String get nightStyleJson;
  Stream<void> get changes;
  String getStyleJson({bool isDarkMode = false});
  Future<void> init();
  Future<bool> refreshOfflineMap({bool emitChange = true});
}
