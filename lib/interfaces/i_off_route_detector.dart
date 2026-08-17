import 'package:equatable/equatable.dart';

/// Kết quả kiểm tra trạng thái lệch lộ trình
class OffRouteStatus extends Equatable {
  final bool isOffRoute;
  final double distanceToRoute;
  final int segmentIndex;
  final List<double>? closestPoint;

  const OffRouteStatus({
    required this.isOffRoute,
    required this.distanceToRoute,
    required this.segmentIndex,
    this.closestPoint,
  });

  @override
  List<Object?> get props => [
        isOffRoute,
        distanceToRoute,
        segmentIndex,
        closestPoint,
      ];
}

/// Interface phát hiện lệch lộ trình cho hệ thống dẫn đường (Navigation)
abstract class IOffRouteDetector {
  /// Ngưỡng khoảng cách tối đa (mét) để coi là đang nằm trên lộ trình (mặc định 50m)
  double get thresholdMeters;

  /// Kiểm tra tọa độ GPS hiện tại có nằm trong hành lang an toàn của lộ trình hay không
  ///
  /// [currentLat], [currentLon]: Tọa độ GPS hiện tại của người dùng
  /// [routePoints]: Danh sách tọa độ các điểm mốc trên đa tuyến [[lat, lon], ...]
  /// [currentSegmentIndex]: Chỉ số đoạn thẳng hiện tại đang theo dõi
  /// [lookAheadSegments]: Số đoạn thẳng kế tiếp để tối ưu hóa sliding window (mặc định 5)
  OffRouteStatus checkOffRoute({
    required double currentLat,
    required double currentLon,
    required List<List<double>> routePoints,
    int currentSegmentIndex = 0,
    int lookAheadSegments = 5,
  });
}
