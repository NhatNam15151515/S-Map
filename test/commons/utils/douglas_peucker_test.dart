import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/utils/douglas_peucker.dart';

void main() {
  group('DouglasPeucker Tests', () {
    test('simplify returns original list if length <= 2', () {
      final single = [
        [10.0, 106.0]
      ];
      expect(DouglasPeucker.simplify(single), equals(single));

      final pair = [
        [10.0, 106.0],
        [10.1, 106.1]
      ];
      expect(DouglasPeucker.simplify(pair), equals(pair));
    });

    test('simplify collapses collinear points into start and end', () {
      // 5 điểm thẳng hàng từ 10.0 đến 10.4
      final collinear = [
        [10.0, 106.0],
        [10.1, 106.1],
        [10.2, 106.2],
        [10.3, 106.3],
        [10.4, 106.4],
      ];

      final simplified = DouglasPeucker.simplify(collinear, toleranceMeters: 5.0);

      expect(simplified.length, equals(2));
      expect(simplified.first, equals([10.0, 106.0]));
      expect(simplified.last, equals([10.4, 106.4]));
    });

    test('simplify retains sharp turn points exceeding tolerance', () {
      // Điểm B lệch hẳn ra xa (gần 1km) tạo thành hình tam giác
      final sharpTurn = [
        [10.7720, 106.6980], // A
        [10.7800, 106.6980], // B (rẽ vuông góc)
        [10.7800, 106.7080], // C
      ];

      final simplified = DouglasPeucker.simplify(sharpTurn, toleranceMeters: 5.0);

      // Điểm B phải được giữ lại
      expect(simplified.length, equals(3));
      expect(simplified[1], equals([10.7800, 106.6980]));
    });
  });
}
