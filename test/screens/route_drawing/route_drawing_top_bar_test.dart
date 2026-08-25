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
        home: Scaffold(
          body: Stack(
            children: [child],
          ),
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

  group('RouteDrawingTopBar Widget Tests', () {
    testWidgets('renders title, back button, profile badge, and saved routes button', (tester) async {
      bool savedRoutesPressed = false;

      await tester.pumpWidget(
        createTestableWidget(
          RouteDrawingTopBar(
            topPadding: 20,
            onSavedRoutesPressed: () {
              savedRoutesPressed = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('route_drawing_back_button')), findsOneWidget);
      expect(find.byKey(const Key('route_drawing_saved_routes_button')), findsOneWidget);
      expect(find.text('Vẽ lộ trình tùy chỉnh'), findsOneWidget);
      expect(find.text('Xe máy'), findsOneWidget);

      // Tap saved routes button
      await tester.tap(find.byKey(const Key('route_drawing_saved_routes_button')));
      await tester.pump();
      expect(savedRoutesPressed, isTrue);
    });
  });
}
