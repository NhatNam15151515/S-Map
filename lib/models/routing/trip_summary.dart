import 'package:equatable/equatable.dart';

/// Thống kê tổng kết sau khi hoàn thành hoặc dừng chuyến đi dẫn đường
class TripSummary extends Equatable {
  /// Tổng thời gian thực hiện chuyến đi
  final Duration duration;

  /// Tổng quãng đường đã di chuyển (đơn vị: mét)
  final double distanceMeters;

  /// Tốc độ trung bình (đơn vị: km/h)
  final double avgSpeedKmh;

  /// Tốc độ tối đa ghi nhận trong suốt chuyến đi (đơn vị: km/h)
  final double topSpeedKmh;

  /// Tên điểm đến
  final String? destinationName;

  /// Cờ xác định xe đã đến đích thành công hay kết thúc sớm
  final bool hasArrived;

  const TripSummary({
    required this.duration,
    required this.distanceMeters,
    required this.avgSpeedKmh,
    required this.topSpeedKmh,
    this.destinationName,
    this.hasArrived = false,
  });

  @override
  List<Object?> get props => [
        duration,
        distanceMeters,
        avgSpeedKmh,
        topSpeedKmh,
        destinationName,
        hasArrived,
      ];
}
