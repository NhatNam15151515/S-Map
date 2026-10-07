import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s_map/commons/widgets/app_button.dart';
import 'package:s_map/generated/codegen_loader.g.dart';
import 'package:s_map/screens/settings/offline_regions/widgets/offline_storage_summary_card.dart';

Widget createTestApp(Widget child) {
  return EasyLocalization(
    supportedLocales: const [Locale('vi'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('vi'),
    startLocale: const Locale('vi'),
    assetLoader: const CodegenLoader(),
    child: Builder(
      builder: (context) => ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (_, __) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: Scaffold(body: child),
        ),
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

  group('OfflineStorageSummaryCard Pure Dumb Widget Tests', () {
    testWidgets('renders formattedStorage text and handles onCheckUpdates tap', (
      tester,
    ) async {
      bool checkedUpdates = false;

      await tester.pumpWidget(
        createTestApp(
          OfflineStorageSummaryCard(
            formattedStorage: '128.5 MB',
            onCheckUpdates: () => checkedUpdates = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('128.5 MB'), findsOneWidget);
      expect(find.byType(AppButton), findsOneWidget);

      await tester.tap(find.byType(AppButton));
      expect(checkedUpdates, isTrue);
    });
  });
}
