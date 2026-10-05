import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/utils/circular_ema_filter.dart';

void main() {
  group('CircularEmaFilter Unit Tests', () {
    test('Initial target bearing initializes filter without smoothing', () {
      final filter = CircularEmaFilter(defaultAlpha: 0.5);
      expect(filter.currentBearing, isNull);

      final result = filter.filter(90.0);
      expect(result, equals(90.0));
      expect(filter.currentBearing, equals(90.0));
    });

    test('Shortest arc interpolation within normal quadrant (10 to 30)', () {
      final filter = CircularEmaFilter(defaultAlpha: 0.5);
      filter.filter(10.0);

      final result = filter.filter(30.0);
      // diff = +20. With alpha = 0.5 => 10 + 0.5 * 20 = 20.0
      expect(result, closeTo(20.0, 0.001));
    });

    test('Shortest arc across 0/360 boundary clockwise (350 to 10)', () {
      final filter = CircularEmaFilter(defaultAlpha: 0.5);
      filter.filter(350.0);

      // Distance from 350 clockwise to 10 is +20 deg (via 0)
      final result = filter.filter(10.0);
      // 350 + 0.5 * (+20) = 360 = 0.0 deg
      expect(result, closeTo(0.0, 0.001));
    });

    test('Shortest arc across 0/360 boundary counter-clockwise (10 to 350)', () {
      final filter = CircularEmaFilter(defaultAlpha: 0.5);
      filter.filter(10.0);

      // Distance from 10 counter-clockwise to 350 is -20 deg (via 0)
      final result = filter.filter(350.0);
      // 10 + 0.5 * (-20) = 0.0 deg
      expect(result, closeTo(0.0, 0.001));
    });

    test('Filter heavily damps jittering magnetometer noise when alpha is small', () {
      final filter = CircularEmaFilter(defaultAlpha: 0.1);
      filter.filter(90.0);

      // Noise spike from 90 to 110 deg
      final damped = filter.filter(110.0);
      // diff = +20. With alpha = 0.1 => 90 + 0.1 * 20 = 92.0 deg
      expect(damped, closeTo(92.0, 0.001));

      // Opposite noise spike down to 70 deg
      final damped2 = filter.filter(70.0);
      // diff = 70 - 92 = -22. Next = 92 + 0.1 * (-22) = 89.8 deg
      expect(damped2, closeTo(89.8, 0.001));
    });

    test('Negative and >360 angles are safely normalized', () {
      final filter = CircularEmaFilter(defaultAlpha: 1.0);
      expect(filter.filter(-90.0), closeTo(270.0, 0.001));
      expect(filter.filter(450.0), closeTo(90.0, 0.001));
    });

    test('Reset clears state and allows re-initialization', () {
      final filter = CircularEmaFilter();
      filter.filter(180.0);
      expect(filter.currentBearing, equals(180.0));

      filter.reset();
      expect(filter.currentBearing, isNull);

      final next = filter.filter(45.0);
      expect(next, equals(45.0));
    });
  });
}
