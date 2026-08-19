import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization/src/easy_localization_controller.dart';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s_map/commons/utils/route_format_helper.dart';
import 'package:s_map/generated/codegen_loader.g.dart';
import 'package:s_map/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    EasyLocalization.logger.enableLevels = [];
    final controller = EasyLocalizationController(
      saveLocale: false,
      useFallbackTranslations: true,
      fallbackLocale: const Locale('vi'),
      startLocale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      assetLoader: const CodegenLoader(),
      path: 'assets/translations',
      useOnlyLangCode: true,
      onLoadError: (e) {},
    );
    await controller.loadTranslations();
    Localization.load(const Locale('vi'), translations: controller.translations);
  });

  group('RouteFormatHelper Unit Tests', () {
    test('formatDistance formats meters and kilometers accurately', () {
      expect(RouteFormatHelper.formatDistance(-10), equals('0 m'));
      expect(RouteFormatHelper.formatDistance(0), equals('0 m'));
      expect(RouteFormatHelper.formatDistance(150), equals('150 m'));
      expect(RouteFormatHelper.formatDistance(999), equals('999 m'));
      expect(RouteFormatHelper.formatDistance(1000), equals('1.0 km'));
      expect(RouteFormatHelper.formatDistance(2540), equals('2.5 km'));
    });

    test('formatDuration formats milliseconds into localized Vietnamese duration', () {
      expect(RouteFormatHelper.formatDuration(0), equals('< 1 phút'));
      expect(RouteFormatHelper.formatDuration(-500), equals('< 1 phút'));
      expect(RouteFormatHelper.formatDuration(30000), equals('< 1 phút'));
      expect(RouteFormatHelper.formatDuration(60000), equals('1 phút'));
      expect(RouteFormatHelper.formatDuration(720000), equals('12 phút'));
      expect(RouteFormatHelper.formatDuration(3600000), equals('1 giờ'));
      expect(RouteFormatHelper.formatDuration(4500000), equals('1 giờ 15 phút'));
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

    test('formatTripDuration formats Duration into localized Vietnamese text', () {
      expect(
        RouteFormatHelper.formatTripDuration(const Duration(seconds: 45)),
        equals('45 giây'),
      );
      expect(
        RouteFormatHelper.formatTripDuration(const Duration(minutes: 10)),
        equals('10 phút'),
      );
      expect(
        RouteFormatHelper.formatTripDuration(const Duration(minutes: 10, seconds: 25)),
        equals('10 phút 25 giây'),
      );
      expect(
        RouteFormatHelper.formatTripDuration(const Duration(hours: 1, minutes: 15)),
        equals('1 giờ 15 phút'),
      );
      expect(
        RouteFormatHelper.formatTripDuration(const Duration(hours: 2)),
        equals('2 giờ'),
      );
    });

    test('getInstructionIcon maps all InstructionType cases to valid IconData', () {
      for (final type in InstructionType.values) {
        final icon = RouteFormatHelper.getInstructionIcon(type);
        expect(icon, isA<IconData>());
      }
    });

    test('getInstructionTitle returns streetName or text or localized default', () {
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
        equals('Đi thẳng'),
      );
    });
  });
}
