import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/codegen_loader.g.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/main/saved/widgets/saved_route_card.dart';

Widget createTestApp(Widget child) {
  return EasyLocalization(
    supportedLocales: const [Locale('vi')],
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

  final sampleRoute = CustomRouteModel(
    id: 'route_123',
    name: 'Cung đường ven biển',
    description: 'Chạy ngắm hoàng hôn Vũng Tàu',
    totalDistance: 15400,
    totalTime: 1800,
    createdAt: DateTime.now(),
    waypoints: const [
      SnappedRoadPoint(
        isSnapped: true,
        originalLat: 10.34,
        originalLon: 107.08,
        snappedLat: 10.34,
        snappedLon: 107.08,
      ),
      SnappedRoadPoint(
        isSnapped: true,
        originalLat: 10.35,
        originalLon: 107.09,
        snappedLat: 10.35,
        snappedLon: 107.09,
      ),
    ],
    fullPolyline: const [
      [10.34, 107.08],
      [10.35, 107.09],
    ],
  );

  group('SavedRouteCard Dumb Widget Tests', () {
    testWidgets('renders route details, buttons, and triggers all callbacks', (
      tester,
    ) async {
      bool viewDrawingCalled = false;
      bool navigationCalled = false;
      bool deleteCalled = false;

      await tester.pumpWidget(
        createTestApp(
          SavedRouteCard(
            route: sampleRoute,
            onViewDrawing: () => viewDrawingCalled = true,
            onStartNavigation: () => navigationCalled = true,
            onDelete: () => deleteCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cung đường ven biển'), findsOneWidget);
      expect(find.text('Chạy ngắm hoàng hôn Vũng Tàu'), findsOneWidget);
      expect(find.byType(AppButton), findsNWidgets(2));
      expect(
        find.byKey(const Key('delete_saved_route_route_123')),
        findsOneWidget,
      );

      // Tap view drawing
      await tester.tap(find.byKey(const Key('view_drawing_btn_route_123')));
      expect(viewDrawingCalled, isTrue);

      // Tap navigation
      await tester.tap(find.byKey(const Key('navigation_btn_route_123')));
      expect(navigationCalled, isTrue);

      // Tap delete
      await tester.tap(find.byKey(const Key('delete_saved_route_route_123')));
      expect(deleteCalled, isTrue);
    });
  });
}
