import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/utils/route_format_helper.dart';
import 'package:s_map/models/models.dart';

void main() {
  group('RouteFormatHelper Unit Tests', () {
    test('formatDistance formats meters and kilometers accurately', () {
      expect(RouteFormatHelper.formatDistance(-10), equals('0 m'));
      expect(RouteFormatHelper.formatDistance(0), equals('0 m'));
      expect(RouteFormatHelper.formatDistance(150), equals('150 m'));
      expect(RouteFormatHelper.formatDistance(999), equals('999 m'));
      expect(RouteFormatHelper.formatDistance(1000), equals('1.0 km'));
      expect(RouteFormatHelper.formatDistance(2540), equals('2.5 km'));
    });

    test('formatDuration formats milliseconds into human-readable duration', () {
      expect(
        RouteFormatHelper.formatDuration(0),
        anyOf(equals('< 1 phút'), equals('routing.sub_minute')),
      );
      expect(
        RouteFormatHelper.formatDuration(-500),
        anyOf(equals('< 1 phút'), equals('routing.sub_minute')),
      );
      expect(
        RouteFormatHelper.formatDuration(30000),
        anyOf(equals('< 1 phút'), equals('routing.sub_minute')),
      );
      expect(
        RouteFormatHelper.formatDuration(60000),
        anyOf(equals('1 phút'), equals('1 routing.unit_minute')),
      );
      expect(
        RouteFormatHelper.formatDuration(720000),
        anyOf(equals('12 phút'), equals('12 routing.unit_minute')),
      );
      expect(
        RouteFormatHelper.formatDuration(3600000),
        anyOf(equals('1 giờ'), equals('1 routing.unit_hour')),
      );
      expect(
        RouteFormatHelper.formatDuration(4500000),
        anyOf(
          equals('1 giờ 15 phút'),
          equals('1 routing.unit_hour 15 routing.unit_minute'),
        ),
      );
    });

    test('formatSpeed formats speed in km/h or fallback correctly', () {
      expect(RouteFormatHelper.formatSpeed(null), equals('--'));
      expect(RouteFormatHelper.formatSpeed(-1.0), equals('--'));
      expect(RouteFormatHelper.formatSpeed(0.0), equals('0'));
      expect(RouteFormatHelper.formatSpeed(34.6), equals('35'));
      expect(RouteFormatHelper.formatSpeed(42.1), equals('42'));
    });

    test('formatEtaClockTime returns formatted HH:mm clock time', () {
      final etaStr = RouteFormatHelper.formatEtaClockTime(600000); // 10 mins
      expect(etaStr, matches(r'^\d{2}:\d{2}$'));
    });

    test('formatTripDuration formats Duration into detailed text', () {
      expect(
        RouteFormatHelper.formatTripDuration(const Duration(seconds: 45)),
        anyOf(equals('45 giây'), equals('45 routing.unit_second')),
      );
      expect(
        RouteFormatHelper.formatTripDuration(const Duration(minutes: 10)),
        anyOf(equals('10 phút'), equals('10 routing.unit_minute')),
      );
      expect(
        RouteFormatHelper.formatTripDuration(const Duration(minutes: 10, seconds: 25)),
        anyOf(
          equals('10 phút 25 giây'),
          equals('10 routing.unit_minute 25 routing.unit_second'),
        ),
      );
      expect(
        RouteFormatHelper.formatTripDuration(const Duration(hours: 1, minutes: 15)),
        anyOf(
          equals('1 giờ 15 phút'),
          equals('1 routing.unit_hour 15 routing.unit_minute'),
        ),
      );
      expect(
        RouteFormatHelper.formatTripDuration(const Duration(hours: 2)),
        anyOf(equals('2 giờ'), equals('2 routing.unit_hour')),
      );
    });

    test('getInstructionIcon maps all InstructionType cases to valid IconData', () {
      for (final type in InstructionType.values) {
        final icon = RouteFormatHelper.getInstructionIcon(type);
        expect(icon, isA<IconData>());
      }
    });

    test('getInstructionTitle returns streetName or text or default', () {
      const withStreet = RouteInstruction(
        text: 'Rẽ phải',
        streetName: 'Đồng Khởi',
        distance: 100,
        time: 10000,
        sign: 2,
        points: [],
      );
      expect(
        RouteFormatHelper.getInstructionTitle(withStreet),
        equals('Đồng Khởi'),
      );

      const withTextOnly = RouteInstruction(
        text: 'Đi về hướng Đông Nam',
        streetName: '',
        distance: 100,
        time: 10000,
        sign: 0,
        points: [],
      );
      expect(
        RouteFormatHelper.getInstructionTitle(withTextOnly),
        equals('Đi về hướng Đông Nam'),
      );

      expect(
        RouteFormatHelper.getInstructionTitle(null),
        anyOf(
          equals('Đi thẳng'),
          equals('routing.continue_straight'),
        ),
      );
    });
  });
}
