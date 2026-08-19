import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';

/// Pure static helper for motorcycle route formatting and UI mapping
class RouteFormatHelper {
  RouteFormatHelper._();

  static const IconData motorcycleIcon = Icons.two_wheeler_rounded;

  /// Định dạng khoảng cách theo mét hoặc kilômét
  static String formatDistance(double distanceMeters) {
    if (distanceMeters < 0) return '0 m';
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    final km = distanceMeters / 1000;
    return '${km.toStringAsFixed(1)} km';
  }

  /// Định dạng thời gian di chuyển từ mili-giây sang giờ và phút
  static String formatDuration(int timeMillis) {
    if (timeMillis < 60000) return tr(LocaleKeys.routing_sub_minute);

    final totalMinutes = (timeMillis / 60000).round();
    final minuteUnit = tr(LocaleKeys.routing_unit_minute);
    final hourUnit = tr(LocaleKeys.routing_unit_hour);

    if (totalMinutes < 60) {
      return '$totalMinutes $minuteUnit';
    }

    final hours = totalMinutes ~/ 60;
    final remainingMinutes = totalMinutes % 60;
    if (remainingMinutes == 0) {
      return '$hours $hourUnit';
    }
    return '$hours $hourUnit $remainingMinutes $minuteUnit';
  }

  /// Định dạng tốc độ hiển thị trên Speedometer
  static String formatSpeed(double? speedKmh) {
    if (speedKmh == null || speedKmh < 0) return '--';
    return '${speedKmh.round()}';
  }

  /// Định dạng mốc thời gian đến đích theo đồng hồ thực tế (HH:mm)
  static String formatEtaClockTime(int remainingDurationMs) {
    final now = DateTime.now();
    final arrivalTime = now.add(
      Duration(milliseconds: remainingDurationMs > 0 ? remainingDurationMs : 0),
    );
    final hourStr = arrivalTime.hour.toString().padLeft(2, '0');
    final minStr = arrivalTime.minute.toString().padLeft(2, '0');
    return '$hourStr:$minStr';
  }

  /// Định dạng tổng thời gian chuyến đi (Duration)
  static String formatTripDuration(Duration duration) {
    final secondUnit = tr(LocaleKeys.routing_unit_second);
    final minuteUnit = tr(LocaleKeys.routing_unit_minute);
    final hourUnit = tr(LocaleKeys.routing_unit_hour);

    final totalSeconds = duration.inSeconds;
    if (totalSeconds < 60) {
      return '$totalSeconds $secondUnit';
    }
    final minutes = duration.inMinutes;
    final seconds = totalSeconds % 60;
    if (minutes < 60) {
      return seconds > 0
          ? '$minutes $minuteUnit $seconds $secondUnit'
          : '$minutes $minuteUnit';
    }
    final hours = duration.inHours;
    final remainingMinutes = minutes % 60;
    return remainingMinutes > 0
        ? '$hours $hourUnit $remainingMinutes $minuteUnit'
        : '$hours $hourUnit';
  }

  /// Ánh xạ InstructionType sang IconData đồ hoạ trực quan
  static IconData getInstructionIcon(InstructionType type) {
    switch (type) {
      case InstructionType.turnSharpLeft:
        return Icons.turn_sharp_left_rounded;
      case InstructionType.turnLeft:
        return Icons.turn_left_rounded;
      case InstructionType.turnSlightLeft:
        return Icons.turn_slight_left_rounded;
      case InstructionType.continueStraight:
        return Icons.straight_rounded;
      case InstructionType.turnSlightRight:
        return Icons.turn_slight_right_rounded;
      case InstructionType.turnRight:
        return Icons.turn_right_rounded;
      case InstructionType.turnSharpRight:
        return Icons.turn_sharp_right_rounded;
      case InstructionType.arrive:
        return Icons.flag_rounded;
      case InstructionType.reachedVia:
        return Icons.place_rounded;
      case InstructionType.uTurnLeft:
      case InstructionType.uTurnUnknown:
        return Icons.u_turn_left_rounded;
      case InstructionType.uTurnRight:
        return Icons.u_turn_right_rounded;
      case InstructionType.useRoundabout:
      case InstructionType.leaveRoundabout:
        return Icons.rotate_right_rounded;
      case InstructionType.keepLeft:
        return Icons.fork_left_rounded;
      case InstructionType.keepRight:
        return Icons.fork_right_rounded;
      case InstructionType.unknown:
        return Icons.navigation_rounded;
    }
  }

  /// Lấy tên đường hoặc mô tả vắn tắt của bước rẽ
  static String getInstructionTitle(RouteInstruction? instruction) {
    if (instruction == null) return tr(LocaleKeys.routing_continue_straight);
    if (instruction.streetName.isNotEmpty) {
      return instruction.streetName;
    }
    if (instruction.text.isNotEmpty) {
      return instruction.text;
    }
    return tr(LocaleKeys.routing_continue_straight);
  }
}
