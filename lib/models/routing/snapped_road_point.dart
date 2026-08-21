import 'package:equatable/equatable.dart';

/// Kết quả nắn / bắt tọa độ GPS vào tim đường gần nhất qua GraphHopper LocationIndex
class SnappedRoadPoint extends Equatable {
  final bool isSnapped;
  final double originalLat;
  final double originalLon;
  final double snappedLat;
  final double snappedLon;
  final String streetName;
  final double distanceToRoad;
  final int edgeId;
  final int calculationTimeMs;
  final String? errorMessage;

  const SnappedRoadPoint({
    required this.isSnapped,
    required this.originalLat,
    required this.originalLon,
    required this.snappedLat,
    required this.snappedLon,
    this.streetName = '',
    this.distanceToRoad = 0.0,
    this.edgeId = -1,
    this.calculationTimeMs = 0,
    this.errorMessage,
  });

  /// Factory tạo fallback khi không tìm thấy đường hoặc engine chưa nạp
  factory SnappedRoadPoint.notSnapped({
    required double originalLat,
    required double originalLon,
    String? errorMessage,
    int calculationTimeMs = 0,
  }) =>
      SnappedRoadPoint(
        isSnapped: false,
        originalLat: originalLat,
        originalLon: originalLon,
        snappedLat: originalLat,
        snappedLon: originalLon,
        errorMessage: errorMessage,
        calculationTimeMs: calculationTimeMs,
      );

  factory SnappedRoadPoint.fromMap(Map<String, dynamic> map) {
    return SnappedRoadPoint(
      isSnapped: map['isSnapped'] as bool? ?? false,
      originalLat: (map['originalLat'] as num?)?.toDouble() ?? 0.0,
      originalLon: (map['originalLon'] as num?)?.toDouble() ?? 0.0,
      snappedLat: (map['snappedLat'] as num?)?.toDouble() ??
          (map['originalLat'] as num?)?.toDouble() ??
          0.0,
      snappedLon: (map['snappedLon'] as num?)?.toDouble() ??
          (map['originalLon'] as num?)?.toDouble() ??
          0.0,
      streetName: map['streetName'] as String? ?? '',
      distanceToRoad: (map['distanceToRoad'] as num?)?.toDouble() ?? 0.0,
      edgeId: (map['edgeId'] as num?)?.toInt() ?? -1,
      calculationTimeMs: (map['calculationTimeMs'] as num?)?.toInt() ?? 0,
      errorMessage: map['errorMessage'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'isSnapped': isSnapped,
        'originalLat': originalLat,
        'originalLon': originalLon,
        'snappedLat': snappedLat,
        'snappedLon': snappedLon,
        'streetName': streetName,
        'distanceToRoad': distanceToRoad,
        'edgeId': edgeId,
        'calculationTimeMs': calculationTimeMs,
        'errorMessage': errorMessage,
      };

  @override
  List<Object?> get props => [
        isSnapped,
        originalLat,
        originalLon,
        snappedLat,
        snappedLon,
        streetName,
        distanceToRoad,
        edgeId,
        calculationTimeMs,
        errorMessage,
      ];
}
