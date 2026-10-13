import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s_map/commons/widgets/app_button.dart';
import 'package:s_map/commons/widgets/app_info_dialog.dart';
import 'package:s_map/generated/codegen_loader.g.dart';
import 'package:s_map/screens/settings/widgets/app_about_dialog.dart';
import 'package:s_map/screens/settings/widgets/policy_dialog.dart';

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
        home: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('PolicyDialog & AppAboutDialog Tests', () {
    testWidgets('PolicyDialog renders title and content correctly', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          const PolicyDialog(
            title: 'Chính sách riêng tư',
            content: 'Nội dung chi tiết chính sách.',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppInfoDialog), findsOneWidget);
      expect(find.text('Chính sách riêng tư'), findsOneWidget);
      expect(find.text('Nội dung chi tiết chính sách.'), findsOneWidget);
      expect(find.byType(AppButton), findsOneWidget);
    });

    testWidgets('AppAboutDialog renders appName and version info', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          const AppAboutDialog(
            appName: 'S-Map Navigation',
            appVersion: '1.2.3',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppInfoDialog), findsOneWidget);
      expect(find.byIcon(Icons.map_rounded), findsOneWidget);
      expect(find.text('S-Map Navigation'), findsOneWidget);
      expect(find.textContaining('1.2.3'), findsOneWidget);
      expect(find.byType(AppButton), findsOneWidget);
    });
  });
}
