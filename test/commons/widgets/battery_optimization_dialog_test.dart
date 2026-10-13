import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/codegen_loader.g.dart';
import 'package:s_map/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget createTestApp(Widget child) {
  return EasyLocalization(
    supportedLocales: const [Locale('vi'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('vi'),
    startLocale: const Locale('vi'),
    assetLoader: const CodegenLoader(),
    child: Builder(
      builder: (context) => MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        home: Scaffold(
          body: Center(child: child),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    EasyLocalization.logger.enableLevels = [];
  });

  group('BatteryOptimizationDialog Widget Tests', () {
    testWidgets('Renders Samsung specific guidance and triggers onAllow callback',
        (tester) async {
      bool allowed = false;
      bool skipped = false;

      await tester.pumpWidget(createTestApp(
        BatteryOptimizationDialog(
          oemType: DeviceOemType.samsung,
          onAllow: () {
            allowed = true;
          },
          onSkip: () {
            skipped = true;
          },
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Tối ưu hóa Pin khi Chạy ngầm'), findsOneWidget);
      expect(find.textContaining('Samsung'), findsOneWidget);
      expect(find.text('Cho phép chạy ngầm'), findsOneWidget);
      expect(find.text('Bỏ qua'), findsOneWidget);

      await tester.tap(find.text('Cho phép chạy ngầm'));
      await tester.pump();

      expect(allowed, isTrue);
      expect(skipped, isFalse);
    });

    testWidgets('Renders Xiaomi specific guidance and triggers onSkip callback',
        (tester) async {
      bool allowed = false;
      bool skipped = false;

      await tester.pumpWidget(createTestApp(
        BatteryOptimizationDialog(
          oemType: DeviceOemType.xiaomi,
          onAllow: () {
            allowed = true;
          },
          onSkip: () {
            skipped = true;
          },
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Xiaomi/Redmi'), findsOneWidget);

      await tester.tap(find.text('Bỏ qua'));
      await tester.pump();

      expect(allowed, isFalse);
      expect(skipped, isTrue);
    });

    testWidgets('Renders generic guidance for generic Android devices',
        (tester) async {
      await tester.pumpWidget(createTestApp(
        BatteryOptimizationDialog(
          oemType: DeviceOemType.genericAndroid,
          onAllow: () {},
          onSkip: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('cho phép ứng dụng chạy ngầm không hạn chế pin'), findsOneWidget);
    });

    testWidgets('PopScope triggers onSkip and closes dialog on system back button',
        (tester) async {
      bool skipped = false;

      await tester.pumpWidget(createTestApp(
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () {
              BatteryOptimizationDialog.show(
                ctx,
                oemType: DeviceOemType.samsung,
                onAllow: () {},
                onSkip: () {
                  skipped = true;
                },
              );
            },
            child: const Text('Open Dialog'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Tối ưu hóa Pin khi Chạy ngầm'), findsOneWidget);

      // Simulate back button via PopScope
      final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
      await widgetsAppState.didPopRoute();
      await tester.pumpAndSettle();

      expect(skipped, isTrue);
      expect(find.text('Tối ưu hóa Pin khi Chạy ngầm'), findsNothing);
      expect(find.text('Open Dialog'), findsOneWidget);
    });
  });
}
