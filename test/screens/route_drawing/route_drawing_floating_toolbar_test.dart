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

  group('RouteDrawingFloatingToolbar Widget Tests', () {
    testWidgets('disabled buttons do not trigger callbacks when flags are false', (tester) async {
      bool undoCalled = false;
      bool redoCalled = false;
      bool clearCalled = false;
      bool fitBoundsCalled = false;

      await tester.pumpWidget(
        createTestableWidget(
          RouteDrawingFloatingToolbar(
            canUndo: false,
            canRedo: false,
            canClear: false,
            hasPoints: false,
            onUndo: () => undoCalled = true,
            onRedo: () => redoCalled = true,
            onClear: () => clearCalled = true,
            onFitBounds: () => fitBoundsCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('route_drawing_undo_button')));
      await tester.tap(find.byKey(const Key('route_drawing_redo_button')));
      await tester.tap(find.byKey(const Key('route_drawing_clear_button')));
      await tester.tap(find.byKey(const Key('route_drawing_fit_bounds_button')));
      await tester.pump();

      expect(undoCalled, isFalse);
      expect(redoCalled, isFalse);
      expect(clearCalled, isFalse);
      expect(fitBoundsCalled, isFalse);
    });

    testWidgets('enabled buttons trigger callbacks correctly', (tester) async {
      bool undoCalled = false;
      bool redoCalled = false;
      bool clearCalled = false;
      bool fitBoundsCalled = false;

      await tester.pumpWidget(
        createTestableWidget(
          RouteDrawingFloatingToolbar(
            canUndo: true,
            canRedo: true,
            canClear: true,
            hasPoints: true,
            onUndo: () => undoCalled = true,
            onRedo: () => redoCalled = true,
            onClear: () => clearCalled = true,
            onFitBounds: () => fitBoundsCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Test Undo
      await tester.tap(find.byKey(const Key('route_drawing_undo_button')));
      await tester.pump();
      expect(undoCalled, isTrue);

      // Test Redo
      await tester.tap(find.byKey(const Key('route_drawing_redo_button')));
      await tester.pump();
      expect(redoCalled, isTrue);

      // Test Fit Bounds
      await tester.tap(find.byKey(const Key('route_drawing_fit_bounds_button')));
      await tester.pump();
      expect(fitBoundsCalled, isTrue);

      // Test Clear: cancel does not trigger onClear
      await tester.tap(find.byKey(const Key('route_drawing_clear_button')));
      await tester.pumpAndSettle();

      expect(find.text('Xóa toàn bộ lộ trình?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('route_drawing_clear_cancel_btn')));
      await tester.pumpAndSettle();
      expect(clearCalled, isFalse);

      // Test Clear: confirm triggers onClear
      await tester.tap(find.byKey(const Key('route_drawing_clear_button')));
      await tester.pumpAndSettle();

      expect(find.text('Xóa toàn bộ lộ trình?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('route_drawing_clear_confirm_btn')));
      await tester.pumpAndSettle();
      expect(clearCalled, isTrue);
    });
  });
}
