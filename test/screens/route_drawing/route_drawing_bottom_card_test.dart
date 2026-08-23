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

  group('RouteDrawingBottomCard Widget Tests', () {
    testWidgets('displays initial tap prompt when pointCount == 0', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          RouteDrawingBottomCard(
            pointCount: 0,
            distanceMeters: 0,
            durationMs: 0,
            isLoading: false,
            onSavePressed: () {},
            onNavigatePressed: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chạm vào bản đồ để chọn điểm bắt đầu'), findsOneWidget);
    });

    testWidgets('displays next waypoint prompt when pointCount == 1', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          RouteDrawingBottomCard(
            pointCount: 1,
            distanceMeters: 0,
            durationMs: 0,
            isLoading: false,
            onSavePressed: () {},
            onNavigatePressed: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chạm điểm tiếp theo để tạo lộ trình'), findsOneWidget);
      expect(find.text('1 điểm mốc'), findsOneWidget);
    });

    testWidgets('displays stats and buttons when pointCount >= 2', (tester) async {
      bool saveCalled = false;
      bool navigateCalled = false;

      await tester.pumpWidget(
        createTestableWidget(
          RouteDrawingBottomCard(
            pointCount: 3,
            distanceMeters: 2500,
            durationMs: 180000,
            isLoading: true,
            onSavePressed: () => saveCalled = true,
            onNavigatePressed: () => navigateCalled = true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('2.5 km'), findsOneWidget);
      expect(find.text('3 phút'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.byKey(const Key('route_drawing_save_button')), findsOneWidget);
      expect(find.byKey(const Key('route_drawing_navigate_button')), findsOneWidget);

      // Tap Save button
      await tester.tap(find.byKey(const Key('route_drawing_save_button')));
      await tester.pump();
      expect(saveCalled, isTrue);

      // Tap Navigate button
      await tester.tap(find.byKey(const Key('route_drawing_navigate_button')));
      await tester.pump();
      expect(navigateCalled, isTrue);
    });
  });
}
