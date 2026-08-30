import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s_map/generated/codegen_loader.g.dart';
import 'package:s_map/screens/route_drawing/widgets/widgets.dart';

Widget createTestableWidget(Widget child) {
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
    EasyLocalization.logger.enableLevels = [];
  });

  group('SaveCustomRouteDialog Widget Tests', () {
    testWidgets('shows validation error when route name is empty and saves on valid input', (tester) async {
      String? savedName;
      String? savedDesc;
      int onSaveCallCount = 0;

      await tester.pumpWidget(
        createTestableWidget(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                SaveCustomRouteDialog.show(
                  context,
                  initialName: 'Lộ trình mới',
                  onSave: (name, desc) {
                    onSaveCallCount++;
                    savedName = name;
                    savedDesc = desc;
                  },
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Lưu Lộ Trình Tùy Biến'), findsOneWidget);
      expect(find.byKey(const Key('save_route_name_input')), findsOneWidget);

      // Clear name to test validation
      await tester.enterText(find.byKey(const Key('save_route_name_input')), '');
      await tester.tap(find.byKey(const Key('save_route_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng nhập tên lộ trình'), findsOneWidget);
      expect(savedName, isNull);
      expect(onSaveCallCount, 0);

      // Enter valid name and description
      await tester.enterText(find.byKey(const Key('save_route_name_input')), 'Cung đường ven biển');
      await tester.enterText(find.byKey(const Key('save_route_desc_input')), 'Đi ngắm hoàng hôn');
      await tester.tap(find.byKey(const Key('save_route_submit_button')));
      await tester.pumpAndSettle();

      expect(savedName, 'Cung đường ven biển');
      expect(savedDesc, 'Đi ngắm hoàng hôn');
      expect(onSaveCallCount, 1);
    });

    testWidgets('trims whitespace and treats empty description as null', (tester) async {
      String? savedName;
      String? savedDesc;
      int onSaveCallCount = 0;

      await tester.pumpWidget(
        createTestableWidget(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                SaveCustomRouteDialog.show(
                  context,
                  initialName: 'Lộ trình mới',
                  onSave: (name, desc) {
                    onSaveCallCount++;
                    savedName = name;
                    savedDesc = desc;
                  },
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Enter name with leading/trailing whitespace, empty description
      await tester.enterText(find.byKey(const Key('save_route_name_input')), '   Đường đèo Hải Vân   ');
      await tester.enterText(find.byKey(const Key('save_route_desc_input')), '   ');
      await tester.tap(find.byKey(const Key('save_route_submit_button')));
      await tester.pumpAndSettle();

      expect(savedName, 'Đường đèo Hải Vân');
      expect(savedDesc, isNull);
      expect(onSaveCallCount, 1);
    });
  });
}
