import 'package:equatable/equatable.dart';

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
