import 'package:equatable/equatable.dart';

/// Các loại hướng chuyển động (Maneuver / Instruction Type) chuẩn GraphHopper
enum InstructionType {
  unknown(-99),
  uTurnUnknown(-98),
  uTurnLeft(-8),
  keepLeft(-7),
  leaveRoundabout(-6),
  turnSharpLeft(-3),
  turnLeft(-2),
  turnSlightLeft(-1),
  continueStraight(0),
  turnSlightRight(1),
  turnRight(2),
  turnSharpRight(3),
  arrive(4),
  reachedVia(5),
  useRoundabout(6),
  keepRight(7),
  uTurnRight(8);

  final int sign;
  const InstructionType(this.sign);

  static InstructionType fromSign(int sign) {
    return InstructionType.values.firstWhere(
      (e) => e.sign == sign,
      orElse: () => InstructionType.unknown,
    );
  }

  bool get isTurnLeft =>
      this == turnLeft || this == turnSharpLeft || this == turnSlightLeft;

  bool get isTurnRight =>
      this == turnRight || this == turnSharpRight || this == turnSlightRight;

  bool get isStraight => this == continueStraight;

  bool get isRoundabout =>
      this == useRoundabout || this == leaveRoundabout;

  bool get isArrive => this == arrive;

  bool get isUTurn =>
      this == uTurnLeft || this == uTurnRight || this == uTurnUnknown;

  bool get isKeepLeft => this == keepLeft;

  bool get isKeepRight => this == keepRight;
}

class RouteInstruction extends Equatable {
  final String text;
  final String streetName;
  final double distance;
  final int time;
  final int sign;
  final List<List<double>> points;

  const RouteInstruction({
    required this.text,
    required this.streetName,
    required this.distance,
    required this.time,
    required this.sign,
    required this.points,
  });

  /// Kiểu hành động chỉ dẫn tương ứng theo mã sign
  InstructionType get type => InstructionType.fromSign(sign);

  /// Tọa độ điểm bắt đầu của chặng chỉ dẫn
  List<double>? get startPoint => points.isNotEmpty ? points.first : null;

  /// Tọa độ điểm kết thúc của chặng chỉ dẫn
  List<double>? get endPoint => points.isNotEmpty ? points.last : null;

  factory RouteInstruction.fromMap(Map<String, dynamic> map) {
    final rawPoints = map['points'] as List<dynamic>? ?? [];
    final parsedPoints = rawPoints
        .map((p) {
          if (p is List) {
            return p.map((coord) => (coord as num).toDouble()).toList();
          }
          return <double>[];
        })
        .where((element) => element.length >= 2)
        .toList();

    return RouteInstruction(
      text: map['text'] as String? ?? '',
      streetName: map['streetName'] as String? ?? '',
      distance: (map['distance'] as num?)?.toDouble() ?? 0.0,
      time: (map['time'] as num?)?.toInt() ?? 0,
      sign: (map['sign'] as num?)?.toInt() ?? 0,
      points: parsedPoints,
    );
  }

  Map<String, dynamic> toMap() => {
        'text': text,
        'streetName': streetName,
        'distance': distance,
        'time': time,
        'sign': sign,
        'points': points,
      };

  @override
  List<Object?> get props => [text, streetName, distance, time, sign, points];
}
