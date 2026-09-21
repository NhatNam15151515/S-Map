import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/utils/map_geometry_utils.dart';

void main() {
  // ── Haversine Distance ─────────────────────────────────────────────

  group('haversineDistanceMeters', () {
    test('returns 0 for identical points', () {
      final d = MapGeometryUtils.haversineDistanceMeters(
          10.7769, 106.7009, 10.7769, 106.7009);
      expect(d, 0.0);
    });

    test('known HCM-HN distance ≈ 1150-1170km', () {
      // HCM: 10.7769, 106.7009 | HN: 21.0285, 105.8542
      final d = MapGeometryUtils.haversineDistanceMeters(
          10.7769, 106.7009, 21.0285, 105.8542);
      expect(d, greaterThan(1140000));
      expect(d, lessThan(1180000));
    });

    test('does NOT produce NaN for nearly identical points', () {
      final d = MapGeometryUtils.haversineDistanceMeters(
          10.7769000001, 106.7009000001, 10.7769000002, 106.7009000002);
      expect(d.isNaN, false);
      expect(d.isInfinite, false);
      expect(d, greaterThanOrEqualTo(0));
    });

    test('does NOT produce NaN for antipodal points', () {
      // Gần đối cực: (0, 0) vs (0, 180)
      final d = MapGeometryUtils.haversineDistanceMeters(0, 0, 0, 180);
      expect(d.isNaN, false);
      expect(d, greaterThan(20000000)); // bán chu vi ~20000km
    });

    test('symmetric: d(A,B) == d(B,A)', () {
      final d1 = MapGeometryUtils.haversineDistanceMeters(
          10.7769, 106.7009, 21.0285, 105.8542);
      final d2 = MapGeometryUtils.haversineDistanceMeters(
          21.0285, 105.8542, 10.7769, 106.7009);
      expect(d1, closeTo(d2, 0.001));
    });
  });

  group('haversineDistanceKm', () {
    test('returns meters / 1000', () {
      final meters = MapGeometryUtils.haversineDistanceMeters(
          10.7769, 106.7009, 10.78, 106.71);
      final km = MapGeometryUtils.haversineDistanceKm(
          10.7769, 106.7009, 10.78, 106.71);
      expect(km, closeTo(meters / 1000.0, 1e-9));
    });
  });

  // ── Point-to-Segment Distance ──────────────────────────────────────

  group('pointToSegmentDistance', () {
    test('point on segment returns ~0 distance', () {
      // Midpoint of A(10.0, 106.0) and B(10.0, 107.0) = (10.0, 106.5)
      final (dist, cLat, cLon) = MapGeometryUtils.pointToSegmentDistance(
        pLat: 10.0, pLon: 106.5,
        aLat: 10.0, aLon: 106.0,
        bLat: 10.0, bLon: 107.0,
      );
      expect(dist, lessThan(1.0)); // < 1 mét
      expect(cLat, closeTo(10.0, 0.001));
      expect(cLon, closeTo(106.5, 0.001));
    });

    test('point at endpoint A', () {
      final (dist, cLat, cLon) = MapGeometryUtils.pointToSegmentDistance(
        pLat: 10.0, pLon: 106.0,
        aLat: 10.0, aLon: 106.0,
        bLat: 10.0, bLon: 107.0,
      );
      expect(dist, lessThan(1.0));
      expect(cLat, closeTo(10.0, 0.001));
      expect(cLon, closeTo(106.0, 0.001));
    });

    test('perpendicular projection from a point north of horizontal segment',
        () {
      // A(10.0, 106.0), B(10.0, 107.0), P(10.01, 106.5) — P is due north of midpoint
      final (dist, cLat, cLon) = MapGeometryUtils.pointToSegmentDistance(
        pLat: 10.01, pLon: 106.5,
        aLat: 10.0, aLon: 106.0,
        bLat: 10.0, bLon: 107.0,
      );
      // 0.01 degree lat ≈ 1113m
      expect(dist, greaterThan(1000));
      expect(dist, lessThan(1200));
      expect(cLat, closeTo(10.0, 0.001));
      expect(cLon, closeTo(106.5, 0.01));
    });

    test('degenerate segment (A == B) returns distance to point', () {
      final (dist, cLat, cLon) = MapGeometryUtils.pointToSegmentDistance(
        pLat: 10.01, pLon: 106.01,
        aLat: 10.0, aLon: 106.0,
        bLat: 10.0, bLon: 106.0,
      );
      expect(dist, greaterThan(1000)); // ~1.5km
      expect(cLat, closeTo(10.0, 0.001));
      expect(cLon, closeTo(106.0, 0.001));
    });

    test('point beyond endpoint B clamps to B', () {
      // A(10.0, 106.0), B(10.0, 106.01), P(10.0, 106.02) — beyond B
      final (dist, _, cLon) = MapGeometryUtils.pointToSegmentDistance(
        pLat: 10.0, pLon: 106.02,
        aLat: 10.0, aLon: 106.0,
        bLat: 10.0, bLon: 106.01,
      );
      expect(cLon, closeTo(106.01, 0.001));
      // Distance should be approx 1 degree * ~111km * cos(10) * 0.01 ≈ 1095m
      expect(dist, greaterThan(900));
      expect(dist, lessThan(1200));
    });
  });

  // ── perpendicularDistanceMeters ────────────────────────────────────

  group('perpendicularDistanceMeters', () {
    test('matches pointToSegmentDistance.distanceMeters exactly', () {
      final (distFull, _, _) = MapGeometryUtils.pointToSegmentDistance(
        pLat: 10.01, pLon: 106.5,
        aLat: 10.0, aLon: 106.0,
        bLat: 10.0, bLon: 107.0,
      );
      final distLite = MapGeometryUtils.perpendicularDistanceMeters(
        10.01, 106.5,
        10.0, 106.0,
        10.0, 107.0,
      );
      expect(distLite, closeTo(distFull, 1e-6));
    });

    test('degenerate segment matches pointToSegmentDistance', () {
      final (distFull, _, _) = MapGeometryUtils.pointToSegmentDistance(
        pLat: 10.01, pLon: 106.01,
        aLat: 10.0, aLon: 106.0,
        bLat: 10.0, bLon: 106.0,
      );
      final distLite = MapGeometryUtils.perpendicularDistanceMeters(
        10.01, 106.01,
        10.0, 106.0,
        10.0, 106.0,
      );
      expect(distLite, closeTo(distFull, 1e-6));
    });
  });

  // ── Fast Distance Squared ──────────────────────────────────────────

  group('fastDistanceSqMeters', () {
    test('ordering matches Haversine for N random points', () {
      final center = (lat: 10.7769, lon: 106.7009);
      final cosRef = math.cos(center.lat * MapGeometryUtils.degToRad);

      // 20 points at varying distances
      final points = <(double lat, double lon)>[
        (10.78, 106.71),
        (10.79, 106.72),
        (10.80, 106.73),
        (10.77, 106.69),
        (10.76, 106.68),
        (10.85, 106.80),
        (10.90, 106.85),
        (10.70, 106.60),
        (10.775, 106.705),
        (10.7770, 106.7010),
      ];

      // Sort by Haversine
      final byHaversine = List<(double, double)>.from(points);
      byHaversine.sort((a, b) {
        final da = MapGeometryUtils.haversineDistanceMeters(
            center.lat, center.lon, a.$1, a.$2);
        final db = MapGeometryUtils.haversineDistanceMeters(
            center.lat, center.lon, b.$1, b.$2);
        return da.compareTo(db);
      });

      // Sort by fastDistanceSq
      final byFast = List<(double, double)>.from(points);
      byFast.sort((a, b) {
        final da = MapGeometryUtils.fastDistanceSqMeters(
            cosRef, center.lat, center.lon, a.$1, a.$2);
        final db = MapGeometryUtils.fastDistanceSqMeters(
            cosRef, center.lat, center.lon, b.$1, b.$2);
        return da.compareTo(db);
      });

      // Same order
      for (int i = 0; i < points.length; i++) {
        expect(byFast[i].$1, byHaversine[i].$1,
            reason: 'Ordering mismatch at index $i');
        expect(byFast[i].$2, byHaversine[i].$2,
            reason: 'Ordering mismatch at index $i');
      }
    });

    test('returns 0 for same point', () {
      final cosRef = math.cos(10.0 * MapGeometryUtils.degToRad);
      final d = MapGeometryUtils.fastDistanceSqMeters(
          cosRef, 10.0, 106.0, 10.0, 106.0);
      expect(d, 0.0);
    });
  });

  // ── Bearing ────────────────────────────────────────────────────────

  group('bearing', () {
    test('due north ≈ 0°', () {
      final b = MapGeometryUtils.bearing(10.0, 106.0, 11.0, 106.0);
      expect(b, closeTo(0.0, 0.5));
    });

    test('due east ≈ 90°', () {
      final b = MapGeometryUtils.bearing(10.0, 106.0, 10.0, 107.0);
      expect(b, closeTo(90.0, 0.5));
    });

    test('due south ≈ 180°', () {
      final b = MapGeometryUtils.bearing(10.0, 106.0, 9.0, 106.0);
      expect(b, closeTo(180.0, 0.5));
    });

    test('due west ≈ 270°', () {
      final b = MapGeometryUtils.bearing(10.0, 106.0, 10.0, 105.0);
      expect(b, closeTo(270.0, 0.5));
    });

    test('result is always in [0, 360)', () {
      final b = MapGeometryUtils.bearing(10.0, 106.0, 9.5, 105.5);
      expect(b, greaterThanOrEqualTo(0));
      expect(b, lessThan(360));
    });
  });

  // ── Polyline Utilities ─────────────────────────────────────────────

  group('polylineLengthMeters', () {
    test('empty or single point returns 0', () {
      expect(MapGeometryUtils.polylineLengthMeters([]), 0.0);
      expect(
          MapGeometryUtils.polylineLengthMeters([
            [10.0, 106.0]
          ]),
          0.0);
    });

    test('sum of segments equals total', () {
      final points = [
        [10.0, 106.0],
        [10.01, 106.0],
        [10.02, 106.0],
      ];
      final total = MapGeometryUtils.polylineLengthMeters(points);
      final seg1 = MapGeometryUtils.haversineDistanceMeters(
          10.0, 106.0, 10.01, 106.0);
      final seg2 = MapGeometryUtils.haversineDistanceMeters(
          10.01, 106.0, 10.02, 106.0);
      expect(total, closeTo(seg1 + seg2, 0.001));
    });
  });

  group('findClosestPointOnPolyline', () {
    final polyline = [
      [10.0, 106.0],
      [10.0, 106.01],
      [10.0, 106.02],
      [10.0, 106.03],
      [10.0, 106.04],
    ];

    test('point near middle segment', () {
      final (segIdx, dist, _, _) = MapGeometryUtils.findClosestPointOnPolyline(
        pLat: 10.0001,
        pLon: 106.025,
        points: polyline,
      );
      expect(segIdx, 2); // segment between index 2 and 3
      expect(dist, lessThan(20)); // ~11m north
    });

    test('point near first endpoint', () {
      final (segIdx, dist, _, _) = MapGeometryUtils.findClosestPointOnPolyline(
        pLat: 10.0001,
        pLon: 106.0001,
        points: polyline,
      );
      expect(segIdx, 0);
      expect(dist, lessThan(20));
    });

    test('empty polyline returns infinity distance', () {
      final (_, dist, _, _) = MapGeometryUtils.findClosestPointOnPolyline(
        pLat: 10.0,
        pLon: 106.0,
        points: [],
      );
      expect(dist, double.infinity);
    });

    test('single point polyline returns haversine distance', () {
      final (segIdx, dist, _, _) = MapGeometryUtils.findClosestPointOnPolyline(
        pLat: 10.01,
        pLon: 106.0,
        points: [
          [10.0, 106.0]
        ],
      );
      expect(segIdx, 0);
      expect(dist, closeTo(
          MapGeometryUtils.haversineDistanceMeters(10.01, 106.0, 10.0, 106.0),
          0.1));
    });
  });

  // ── Bounding Box ──────────────────────────────────────────────────

  group('boundingBoxDelta', () {
    test('deltaLat matches radius / metersPerDegreeLat', () {
      final (deltaLat, _) = MapGeometryUtils.boundingBoxDelta(10.0, 1000.0);
      expect(deltaLat, closeTo(1000.0 / 111320.0, 1e-9));
    });

    test('deltaLon accounts for cos(lat)', () {
      final (_, deltaLon) = MapGeometryUtils.boundingBoxDelta(10.0, 1000.0);
      final expected =
          1000.0 / (111320.0 * math.cos(10.0 * MapGeometryUtils.degToRad));
      expect(deltaLon, closeTo(expected, 1e-9));
    });

    test('at equator deltaLat ≈ deltaLon', () {
      final (deltaLat, deltaLon) =
          MapGeometryUtils.boundingBoxDelta(0.0, 1000.0);
      expect(deltaLat, closeTo(deltaLon, 1e-6));
    });

    test('at high latitude deltaLon > deltaLat', () {
      final (deltaLat, deltaLon) =
          MapGeometryUtils.boundingBoxDelta(60.0, 1000.0);
      expect(deltaLon, greaterThan(deltaLat));
    });
  });
}
