import 'package:s_map/models/models.dart';

/// Lưu các POI người dùng đã thực sự đến nơi để hiển thị lại trên bản đồ.
abstract class IVisitedPoiService {
  Future<void> init();

  Future<List<PoiModel>> getVisitedPois();

  Future<void> recordVisited(PoiModel poi);

  Future<void> clearVisitedPois();

  Stream<List<PoiModel>> watchVisitedPois();
}
