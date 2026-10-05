import 'package:s_map/models/routing/route_instruction.dart';

/// Sinh câu nói tiếng Việt cho giọng nói dẫn đường (TTS).
///
/// Pure functions — không phụ thuộc bất kỳ service nào, dễ test.
/// Câu nói được thiết kế ngắn gọn, rõ ràng, phù hợp khi đi xe máy
/// (người dùng nghe qua loa ngoài hoặc tai nghe, tốc độ cao, ồn ào).
class VoiceInstructionBuilder {
  VoiceInstructionBuilder._();

  /// Sinh câu thông báo trước (cách ngã rẽ ~200m).
  ///
  /// Ví dụ: "200 mét nữa, rẽ phải vào đường Nguyễn Trãi"
  static String buildPreAnnounce({
    required InstructionType type,
    required String streetName,
    required double distanceMeters,
  }) {
    final distStr = _formatDistanceForSpeech(distanceMeters);
    final turnStr = _instructionTypeToVietnamese(type);
    final streetStr = streetName.trim();

    if (streetStr.isNotEmpty) {
      return '$distStr nữa, $turnStr vào $streetStr';
    }
    return '$distStr nữa, $turnStr';
  }

  /// Sinh câu thông báo tại ngã rẽ (cách ~30m).
  ///
  /// Ví dụ: "Rẽ phải ngay"
  static String buildAtTurn({
    required InstructionType type,
    required String streetName,
  }) {
    final turnStr = _instructionTypeToVietnamese(type);
    final streetStr = streetName.trim();

    if (streetStr.isNotEmpty) {
      return '$turnStr vào $streetStr ngay';
    }
    return '$turnStr ngay';
  }

  /// Sinh câu thông báo đến đích.
  ///
  /// Ví dụ: "Bạn đã đến Bách Hóa Xanh"
  static String buildArrival({String? destinationName}) {
    final name = destinationName?.trim();
    if (name != null && name.isNotEmpty) {
      return 'Bạn đã đến $name';
    }
    return 'Bạn đã đến nơi';
  }

  /// Câu thông báo khi tính lại đường.
  static String buildRerouting() => 'Đang tính lại đường';

  /// Câu thông báo khi trở lại tuyến đường.
  static String buildBackOnRoute() => 'Đã trở lại tuyến đường';

  // ============================================================
  // Private helpers
  // ============================================================

  static String _instructionTypeToVietnamese(InstructionType type) {
    switch (type) {
      case InstructionType.turnLeft:
        return 'rẽ trái';
      case InstructionType.turnSlightLeft:
        return 'rẽ chếch trái';
      case InstructionType.turnSharpLeft:
        return 'rẽ gấp trái';
      case InstructionType.turnRight:
        return 'rẽ phải';
      case InstructionType.turnSlightRight:
        return 'rẽ chếch phải';
      case InstructionType.turnSharpRight:
        return 'rẽ gấp phải';
      case InstructionType.continueStraight:
        return 'đi thẳng';
      case InstructionType.useRoundabout:
        return 'vào vòng xuyến';
      case InstructionType.leaveRoundabout:
        return 'ra vòng xuyến';
      case InstructionType.keepLeft:
        return 'đi về phía trái';
      case InstructionType.keepRight:
        return 'đi về phía phải';
      case InstructionType.uTurnLeft:
      case InstructionType.uTurnRight:
      case InstructionType.uTurnUnknown:
        return 'quay đầu';
      case InstructionType.arrive:
        return 'đến nơi';
      case InstructionType.reachedVia:
        return 'đã qua điểm dừng';
      case InstructionType.unknown:
        return 'tiếp tục';
    }
  }

  /// Format khoảng cách cho giọng nói — làm tròn để dễ nghe.
  ///
  /// - Dưới 100m: làm tròn 10m ("30 mét", "50 mét")
  /// - 100-999m: làm tròn 50m ("200 mét", "350 mét")
  /// - Trên 1km: "1 ki-lô-mét", "2 phẩy 5 ki-lô-mét"
  static String _formatDistanceForSpeech(double meters) {
    if (meters < 100) {
      final rounded = (meters / 10).round() * 10;
      return '${rounded.clamp(10, 90)} mét';
    } else if (meters < 1000) {
      final rounded = (meters / 50).round() * 50;
      return '$rounded mét';
    } else {
      final km = meters / 1000;
      if (km == km.roundToDouble()) {
        return '${km.round()} ki lô mét';
      }
      // Làm tròn 0.5km
      final roundedKm = (km * 2).round() / 2;
      if (roundedKm == roundedKm.roundToDouble()) {
        return '${roundedKm.round()} ki lô mét';
      }
      return '${roundedKm.toStringAsFixed(1).replaceAll('.', ' phẩy ')} ki lô mét';
    }
  }
}
