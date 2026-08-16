import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/utils/route_format_helper.dart';

void main() {
  group('RouteFormatHelper Unit Tests (Motorcycle Optimized)', () {
    group('formatDistance', () {
      test('formats meters correctly for distances under 1 km', () {
        expect(RouteFormatHelper.formatDistance(0), equals('0 m'));
        expect(RouteFormatHelper.formatDistance(150), equals('150 m'));
        expect(RouteFormatHelper.formatDistance(999), equals('999 m'));
        expect(RouteFormatHelper.formatDistance(-50), equals('0 m'));
      });

      test('formats kilometers correctly for distances 1 km and above', () {
        expect(RouteFormatHelper.formatDistance(1000), equals('1.0 km'));
        expect(RouteFormatHelper.formatDistance(2500), equals('2.5 km'));
        expect(RouteFormatHelper.formatDistance(12540), equals('12.5 km'));
      });
    });

    group('formatDuration', () {
      test('formats durations under 1 minute', () {
        expect(RouteFormatHelper.formatDuration(0), equals('< 1 phút'));
        expect(RouteFormatHelper.formatDuration(-100), equals('< 1 phút'));
        expect(RouteFormatHelper.formatDuration(25000), equals('< 1 phút'));
      });

      test('formats durations in minutes under 1 hour', () {
        expect(RouteFormatHelper.formatDuration(60000), equals('1 phút'));
        expect(RouteFormatHelper.formatDuration(1500000), equals('25 phút'));
        expect(RouteFormatHelper.formatDuration(3540000), equals('59 phút'));
      });

      test('formats durations 1 hour and above with hours and remaining minutes', () {
        expect(RouteFormatHelper.formatDuration(3600000), equals('1 giờ'));
        expect(RouteFormatHelper.formatDuration(4500000), equals('1 giờ 15 phút'));
        expect(RouteFormatHelper.formatDuration(7200000), equals('2 giờ'));
        expect(RouteFormatHelper.formatDuration(9000000), equals('2 giờ 30 phút'));
      });
    });

    group('motorcycleIcon', () {
      test('motorcycleIcon returns two_wheeler icon', () {
        expect(RouteFormatHelper.motorcycleIcon, equals(Icons.two_wheeler_rounded));
      });
    });
  });
}
