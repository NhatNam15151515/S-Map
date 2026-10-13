import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/generated/codegen_loader.g.dart';
import 'package:s_map/screens/main/home/widgets/map/home_map_controls.dart';

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

  late MapDisplayCubit mapCubit;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    EasyLocalization.logger.enableLevels = [];
  });

  setUp(() {
    mapCubit = MapDisplayCubit();
  });

  tearDown(() async {
    await mapCubit.close();
  });

  group('HomeMapControls Drawing Mode Tests', () {
    testWidgets('reverse and crosshair controls remain available', (tester) async {
      var reverseCalled = false;
      var crosshairCalled = false;

      await tester.pumpWidget(
        createTestableWidget(
          HomeMapControls(
            bottom: 16,
            displayCubit: mapCubit,
            isDrawingMode: true,
            canReverse: true,
            isCrosshairActive: true,
            onReverseRoute: () => reverseCalled = true,
            onToggleCrosshair: () => crosshairCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('route_drawing_reverse_button')));
      await tester.tap(find.byKey(const Key('route_drawing_crosshair_button')));
      await tester.pump();

      expect(reverseCalled, isTrue);
      expect(crosshairCalled, isTrue);
      expect(find.byKey(const Key('route_drawing_undo_button')), findsNothing);
      expect(find.byKey(const Key('route_drawing_redo_button')), findsNothing);
      expect(find.byKey(const Key('route_drawing_clear_button')), findsNothing);
    });

    testWidgets('hides drawing controls when isDrawingMode is false', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          HomeMapControls(
            displayCubit: mapCubit,
            isDrawingMode: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('route_drawing_reverse_button')), findsNothing);
      expect(find.byKey(const Key('route_drawing_crosshair_button')), findsNothing);
    });
  });
}
