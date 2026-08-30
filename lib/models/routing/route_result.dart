import 'package:equatable/equatable.dart';
import 'package:s_map/models/routing/route_instruction.dart';

class RouteResult extends Equatable {
  final bool isSuccess;
  final double distance;
  final int time;
  final List<List<double>> points;
  final List<double>? bbox;
  final List<RouteInstruction> instructions;
  final String? errorMessage;
  final int calculationTimeMs;

  const RouteResult({
    required this.isSuccess,
    this.distance = 0.0,
    this.time = 0,
    this.points = const [],
    this.bbox,
    this.instructions = const [],
    this.errorMessage,
    this.calculationTimeMs = 0,
  });

  bool get isFailure => !isSuccess;
  bool get hasInstructions => instructions.isNotEmpty;
  bool get hasPoints => points.isNotEmpty;

  factory RouteResult.failure(String errorMessage,
      [int calculationTimeMs = 0]) {
    return RouteResult(
      isSuccess: false,
      errorMessage: errorMessage,
      calculationTimeMs: calculationTimeMs,
    );
  }

  factory RouteResult.fromMap(Map<String, dynamic> map) {
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

    final rawBbox = map['bbox'] as List<dynamic>?;
    final parsedBbox =
        rawBbox?.map((coord) => (coord as num).toDouble()).toList();

    final rawInstructions = map['instructions'] as List<dynamic>? ?? [];
    final parsedInstructions = rawInstructions.map((ins) {
      if (ins is Map) {
        return RouteInstruction.fromMap(Map<String, dynamic>.from(ins));
      }
      return const RouteInstruction(
        text: '',
        streetName: '',
        distance: 0.0,
        time: 0,
        sign: 0,
        points: [],
      );
    }).toList();

    return RouteResult(
      isSuccess: map['isSuccess'] as bool? ?? false,
      distance: (map['distance'] as num?)?.toDouble() ?? 0.0,
      time: (map['time'] as num?)?.toInt() ?? 0,
      points: parsedPoints,
      bbox: parsedBbox,
      instructions: parsedInstructions,
      errorMessage: map['errorMessage'] as String?,
      calculationTimeMs: (map['calculationTimeMs'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'isSuccess': isSuccess,
        'distance': distance,
        'time': time,
        'points': points,
        'bbox': bbox,
        'instructions': instructions.map((e) => e.toMap()).toList(),
        'errorMessage': errorMessage,
        'calculationTimeMs': calculationTimeMs,
      };

  @override
  List<Object?> get props => [
        isSuccess,
        distance,
        time,
        points,
        bbox,
        instructions,
        errorMessage,
        calculationTimeMs,
      ];
}
