import 'package:equatable/equatable.dart';
import 'package:s_map/models/routing/route_instruction.dart';

/// Mô hình biểu diễn tiến trình chỉ dẫn từng bước (Turn-by-turn Progress)
class InstructionProgress extends Equatable {
  /// Chỉ số của chỉ dẫn hiện tại trong danh sách instructions
  final int currentInstructionIndex;

  /// Chỉ dẫn đang áp dụng cho chặng hiện tại
  final RouteInstruction? currentInstruction;

  /// Chỉ dẫn kế tiếp (nếu có)
  final RouteInstruction? nextInstruction;

  /// Khoảng cách (mét) từ vị trí hiện tại tới điểm rẽ/mốc chuyển hướng tiếp theo
  final double distanceToNextInstruction;

  /// Tổng khoảng cách còn lại (mét) của toàn bộ lộ trình
  final double remainingDistance;

  /// Tổng thời gian di chuyển ước tính còn lại (mili-giây)
  final int remainingDurationMs;

  /// Cờ báo hiệu đang nằm trong vùng cảnh báo trước (khoảng cách <= 200m)
  final bool isPreAnnounced;

  /// Cờ báo hiệu đã đến đích lộ trình
  final bool hasArrived;

  const InstructionProgress({
    this.currentInstructionIndex = 0,
    this.currentInstruction,
    this.nextInstruction,
    this.distanceToNextInstruction = 0.0,
    this.remainingDistance = 0.0,
    this.remainingDurationMs = 0,
    this.isPreAnnounced = false,
    this.hasArrived = false,
  });

  const InstructionProgress.initial({
    this.currentInstruction,
    this.nextInstruction,
    this.distanceToNextInstruction = 0.0,
    this.remainingDistance = 0.0,
    this.remainingDurationMs = 0,
  })  : currentInstructionIndex = 0,
        isPreAnnounced = false,
        hasArrived = false;

  InstructionProgress copyWith({
    int? currentInstructionIndex,
    RouteInstruction? currentInstruction,
    bool clearCurrentInstruction = false,
    RouteInstruction? nextInstruction,
    bool clearNextInstruction = false,
    double? distanceToNextInstruction,
    double? remainingDistance,
    int? remainingDurationMs,
    bool? isPreAnnounced,
    bool? hasArrived,
  }) {
    return InstructionProgress(
      currentInstructionIndex:
          currentInstructionIndex ?? this.currentInstructionIndex,
      currentInstruction: clearCurrentInstruction
          ? null
          : (currentInstruction ?? this.currentInstruction),
      nextInstruction: clearNextInstruction
          ? null
          : (nextInstruction ?? this.nextInstruction),
      distanceToNextInstruction:
          distanceToNextInstruction ?? this.distanceToNextInstruction,
      remainingDistance: remainingDistance ?? this.remainingDistance,
      remainingDurationMs: remainingDurationMs ?? this.remainingDurationMs,
      isPreAnnounced: isPreAnnounced ?? this.isPreAnnounced,
      hasArrived: hasArrived ?? this.hasArrived,
    );
  }

  @override
  List<Object?> get props => [
        currentInstructionIndex,
        currentInstruction,
        nextInstruction,
        distanceToNextInstruction,
        remainingDistance,
        remainingDurationMs,
        isPreAnnounced,
        hasArrived,
      ];
}
