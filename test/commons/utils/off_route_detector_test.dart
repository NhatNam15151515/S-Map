import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/utils/off_route_detector.dart';

void main() {
  group('OffRouteDetector Unit Tests', () {
    const detector = OffRouteDetector(thresholdMeters: 50.0);

    // Tuyến đường thực tế dọc đường Lê Lợi & Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh
    // Điểm 0: Bến Thành (10.7725, 106.6980)
    // Điểm 1: Ngã 4 Lê Lợi - Pasteur (10.7738, 106.6998)
    // Điểm 2: Nhà hát Thành Phố (10.7766, 106.7032)
    // Điểm 3: Ngã tư Nguyễn Huệ - Ngô Đức Kế (10.7745, 106.7051)
    // Điểm 4: Bến Bạch Đằng (10.7718, 106.7068)
    final hcmcRoute = <List<double>>[
      [10.7725, 106.6980], // Segment 0: A
      [10.7738, 106.6998], // Segment 0: B / Segment 1: A
      [10.7766, 106.7032], // Segment 1: B / Segment 2: A
      [10.7745, 106.7051], // Segment 2: B / Segment 3: A
      [10.7718, 106.7068], // Segment 3: B
    ];

    test('calculatePointToSegmentDistance calculates orthogonal distance precisely', () {
      const aLat = 10.7725;
      const aLon = 106.6980;
      const bLat = 10.7725;
      const bLon = 106.7000; // Đoạn thẳng nằm ngang dọc theo vĩ độ 10.7725

      // Điểm P nằm chính giữa đoạn AB và cách về phía Bắc khoảng ~22.2m (0.0002 độ vĩ)
      const pLat = 10.7727;
      const pLon = 106.6990;

      final (dist, cLat, cLon) = OffRouteDetector.calculatePointToSegmentDistance(
        pLat: pLat,
        pLon: pLon,
        aLat: aLat,
        aLon: aLon,
        bLat: bLat,
        bLon: bLon,
      );

      expect(dist, greaterThan(20.0));
      expect(dist, lessThan(25.0));
      expect(cLat, closeTo(aLat, 0.00001));
      expect(cLon, closeTo(pLon, 0.00001));
    });

    test('calculatePointToSegmentDistance handles point projected beyond endpoints', () {
      const aLat = 10.7725;
      const aLon = 106.6980;
      const bLat = 10.7725;
      const bLon = 106.7000;

      // Điểm P nằm vượt ra ngoài đầu B
      const pLat = 10.7725;
      const pLon = 106.7010;

      final (dist, cLat, cLon) = OffRouteDetector.calculatePointToSegmentDistance(
        pLat: pLat,
        pLon: pLon,
        aLat: aLat,
        aLon: aLon,
        bLat: bLat,
        bLon: bLon,
      );

      // Điểm gần nhất phải là điểm B
      expect(cLat, equals(bLat));
      expect(cLon, equals(bLon));
      expect(dist, greaterThan(100.0));
      expect(dist, lessThan(120.0));
    });

    test('calculatePointToSegmentDistance handles degenerate segment where A == B', () {
      const aLat = 10.7725;
      const aLon = 106.6980;
      const pLat = 10.7728;
      const pLon = 106.6980;

      final (dist, cLat, cLon) = OffRouteDetector.calculatePointToSegmentDistance(
        pLat: pLat,
        pLon: pLon,
        aLat: aLat,
        aLon: aLon,
        bLat: aLat,
        bLon: aLon,
      );

      expect(cLat, equals(aLat));
      expect(cLon, equals(aLon));
      expect(dist, greaterThan(30.0));
      expect(dist, lessThan(36.0));
    });

    test('checkOffRoute returns isOffRoute: false when vehicle is within 50m of route', () {
      // Vị trí người dùng ngay trên đoạn segment 0 (Lê Lợi, gần Bến Thành)
      const userLat = 10.7729;
      const userLon = 106.6986;

      final status = detector.checkOffRoute(
        currentLat: userLat,
        currentLon: userLon,
        routePoints: hcmcRoute,
        currentSegmentIndex: 0,
      );

      expect(status.isOffRoute, isFalse);
      expect(status.distanceToRoute, lessThan(20.0));
      expect(status.segmentIndex, equals(0));
      expect(status.closestPoint, isNotNull);
      expect(status.closestPoint!.length, equals(2));
    });

    test('checkOffRoute returns isOffRoute: true when vehicle deviates > 50m from route', () {
      // Vị trí người dùng rẽ sang đường Nam Kỳ Khởi Nghĩa cách xa hơn 120m
      const userLat = 10.7750;
      const userLon = 106.6980;

      final status = detector.checkOffRoute(
        currentLat: userLat,
        currentLon: userLon,
        routePoints: hcmcRoute,
        currentSegmentIndex: 0,
      );

      expect(status.isOffRoute, isTrue);
      expect(status.distanceToRoute, greaterThan(50.0));
      expect(status.closestPoint, isNotNull);
    });

    test('checkOffRoute correctly advances segmentIndex as vehicle travels along the route', () {
      // Vị trí 1: gần Segment 0
      final status1 = detector.checkOffRoute(
        currentLat: 10.7730,
        currentLon: 106.6988,
        routePoints: hcmcRoute,
        currentSegmentIndex: 0,
      );
      expect(status1.isOffRoute, isFalse);
      expect(status1.segmentIndex, equals(0));

      // Vị trí 2: di chuyển đến gần Nhà hát TP (Segment 1)
      final status2 = detector.checkOffRoute(
        currentLat: 10.7760,
        currentLon: 106.7025,
        routePoints: hcmcRoute,
        currentSegmentIndex: status1.segmentIndex,
      );
      expect(status2.isOffRoute, isFalse);
      expect(status2.segmentIndex, equals(1));

      // Vị trí 3: di chuyển đến Bến Bạch Đằng (Segment 3)
      final status3 = detector.checkOffRoute(
        currentLat: 10.7722,
        currentLon: 106.7065,
        routePoints: hcmcRoute,
        currentSegmentIndex: status2.segmentIndex,
      );
      expect(status3.isOffRoute, isFalse);
      expect(status3.segmentIndex, equals(3));
    });

    test('checkOffRoute handles shortcut jump via global scan fallback', () {
      // Tạo lộ trình dài 20 điểm
      final longRoute = <List<double>>[];
      for (int i = 0; i < 20; i++) {
        longRoute.add([10.7700 + i * 0.001, 106.6900 + i * 0.001]);
      }

      // Người dùng đang ở segment 1 nhưng bất ngờ nhảy cóc sang segment 15
      final shortcutLat = longRoute[15][0] + 0.00005; // lệch ~5m so với segment 15
      final shortcutLon = longRoute[15][1];

      final status = detector.checkOffRoute(
        currentLat: shortcutLat,
        currentLon: shortcutLon,
        routePoints: longRoute,
        currentSegmentIndex: 1,
        lookAheadSegments: 5, // Cửa sổ trượt chỉ tới segment 6
      );

      // Nhờ fallback global scan, phát hiện ra segment 15 mà không báo lệch giả
      expect(status.isOffRoute, isFalse);
      expect(status.segmentIndex, isIn([14, 15]));
      expect(status.distanceToRoute, lessThan(15.0));
    });

    test('checkOffRoute handles empty and single-point lists gracefully', () {
      final emptyStatus = detector.checkOffRoute(
        currentLat: 10.7725,
        currentLon: 106.6980,
        routePoints: const [],
      );
      expect(emptyStatus.isOffRoute, isTrue);
      expect(emptyStatus.distanceToRoute, equals(double.infinity));

      final singlePointRoute = [
        [10.7725, 106.6980]
      ];
      final singleCloseStatus = detector.checkOffRoute(
        currentLat: 10.7726,
        currentLon: 106.6980,
        routePoints: singlePointRoute,
      );
      expect(singleCloseStatus.isOffRoute, isFalse);
      expect(singleCloseStatus.distanceToRoute, lessThan(20.0));

      final singleFarStatus = detector.checkOffRoute(
        currentLat: 10.7800,
        currentLon: 106.7000,
        routePoints: singlePointRoute,
      );
      expect(singleFarStatus.isOffRoute, isTrue);
      expect(singleFarStatus.distanceToRoute, greaterThan(50.0));
    });

    test('OffRouteDetector benchmark: executes 100 iterations on 100-point route in under 5ms', () {
      final largeRoute = <List<double>>[];
      for (int i = 0; i < 100; i++) {
        largeRoute.add([10.7700 + i * 0.0005, 106.6900 + i * 0.0005]);
      }

      final stopwatch = Stopwatch()..start();
      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        final sampleLat = 10.7700 + (i % 95) * 0.0005 + 0.0001;
        final sampleLon = 106.6900 + (i % 95) * 0.0005;

        final result = detector.checkOffRoute(
          currentLat: sampleLat,
          currentLon: sampleLon,
          routePoints: largeRoute,
          currentSegmentIndex: (i % 90),
          lookAheadSegments: 5,
        );

        expect(result.distanceToRoute.isFinite, isTrue);
      }

      stopwatch.stop();
      final avgMicroseconds = (stopwatch.elapsedMicroseconds / iterations).round();

      // GPS loop budget là 16ms, yêu cầu mỗi lần check < 1ms (< 1000us)
      expect(avgMicroseconds, lessThan(500),
          reason: 'Average execution time should be < 500us (Actual: ${avgMicroseconds}us)');
    });
  });
}
