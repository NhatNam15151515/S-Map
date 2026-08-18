import 'package:s_map/models/models.dart';

/// Interface cho bộ máy phân tích và điều phối chỉ dẫn rẽ từng chặng (Turn-by-turn Engine)
abstract class ITurnByTurnEngine {
  /// Ngưỡng khoảng cách tối đa (mét) để chuyển sang chỉ dẫn tiếp theo (mặc định 30.0m)
  double get advanceThresholdMeters;

  /// Ngưỡng khoảng cách tối đa (mét) để kích hoạt trạng thái thông báo trước (mặc định 200.0m)
  double get preAnnounceThresholdMeters;

  /// Ngưỡng khoảng cách tối đa (mét) để xác nhận đã đến đích (mặc định 20.0m)
  double get arrivalThresholdMeters;

  /// Khởi tạo trạng thái tiến trình chỉ dẫn ban đầu cho lộ trình
  InstructionProgress initializeProgress(List<RouteInstruction> instructions);

  /// Cập nhật tiến trình dẫn đường dựa trên tọa độ GPS thực tế
  ///
  /// [currentLat], [currentLon]: Tọa độ GPS hiện tại
  /// [instructions]: Danh sách các chỉ dẫn rẽ trên lộ trình
  /// [currentInstructionIndex]: Chỉ số chỉ dẫn hiện tại
  /// [routePoints]: Danh sách tọa độ đa tuyến polyline
  /// [currentSegmentIndex]: Chỉ số đoạn polyline hiện tại
  InstructionProgress updateProgress({
    required double currentLat,
    required double currentLon,
    required List<RouteInstruction> instructions,
    required int currentInstructionIndex,
    List<List<double>> routePoints = const [],
    int currentSegmentIndex = 0,
  });
}
