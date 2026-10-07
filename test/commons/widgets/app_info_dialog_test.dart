import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s_map/commons/widgets/app_button.dart';
import 'package:s_map/commons/widgets/app_info_dialog.dart';
import 'package:s_map/generated/codegen_loader.g.dart';

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

  group('AppInfoDialog Reusable Dumb Widget Tests', () {
    testWidgets('renders title and string message with close button', (
      tester,
    ) async {
      bool closed = false;

      await tester.pumpWidget(
        createTestApp(
          AppInfoDialog(
            title: 'Chính sách bảo mật',
            message: 'Nội dung điều khoản bảo mật...',
            onClose: () => closed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chính sách bảo mật'), findsOneWidget);
      expect(find.text('Nội dung điều khoản bảo mật...'), findsOneWidget);
      expect(find.byType(AppButton), findsOneWidget);

      await tester.tap(find.byType(AppButton));
      expect(closed, isTrue);
    });

    testWidgets('renders custom icon and custom widget content', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          const AppInfoDialog(
            icon: Icons.map_rounded,
            title: 'S-Map',
            content: Text('Nội dung tùy biến'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.map_rounded), findsOneWidget);
      expect(find.text('S-Map'), findsOneWidget);
      expect(find.text('Nội dung tùy biến'), findsOneWidget);
    });
  });
}
