import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/generated/codegen_loader.g.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/route_drawing/route_drawing_screen.dart';
import 'package:s_map/screens/route_drawing/widgets/widgets.dart';

class MockRoutingRepo implements IRoutingRepository {
  @override
  Future<RouteResult> calculateRoute({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    String? vehicleProfile,
  }) async =>
      const RouteResult(
        isSuccess: true,
        distance: 1500,
        time: 120000,
        points: [
          [10.7, 106.7],
          [10.8, 106.8],
        ],
      );

  @override
  Future<SnappedRoadPoint> snapToRoad({
    required double lat,
    required double lon,
  }) async =>
      SnappedRoadPoint(
        isSnapped: true,
        originalLat: lat,
        originalLon: lon,
        snappedLat: lat,
        snappedLon: lon,
      );

  @override
  Future<bool> initializeEngine(String graphPath) async => true;

  @override
  Future<bool> isEngineReady() async => true;

  @override
  Future<bool> dispose() async => true;
}

class MockCustomRouteRepo implements ICustomRouteRepository {
  @override
  Future<List<CustomRouteModel>> getSavedRoutes() async => [];

  @override
  Future<CustomRouteModel?> getRouteById(String id) async => null;

  @override
  Future<void> saveRoute(CustomRouteModel route) async {}

  @override
  Future<void> deleteRoute(String id) async {}

  @override
  Future<void> clearAllRoutes() async {}

  @override
  Stream<List<CustomRouteModel>> watchSavedRoutes() => Stream.value([]);
}

Widget createTestableWidget({
  required RouteDrawingBloc drawingBloc,
  required SavedRoutesCubit savedRoutesCubit,
  required MapDisplayCubit mapDisplayCubit,
}) {
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
        home: RouteDrawingScreen(
          drawingBloc: drawingBloc,
          savedRoutesCubit: savedRoutesCubit,
          mapDisplayCubit: mapDisplayCubit,
          mapLayerBuilder: () => const SizedBox.expand(
            key: Key('mock_map_layer'),
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

  group('RouteDrawingScreen Integration Widget Tests', () {
    testWidgets('renders all major components and responds to state changes', (tester) async {
      final mockRouting = MockRoutingRepo();
      final mockCustom = MockCustomRouteRepo();

      final drawingBloc = RouteDrawingBloc(
        routingRepository: mockRouting,
        customRouteRepository: mockCustom,
      );
      final savedCubit = SavedRoutesCubit(
        customRouteRepository: mockCustom,
        autoInit: false,
        autoWatch: false,
      );
      final mapCubit = MapDisplayCubit();

      // Đảm bảo cleanup luôn được gọi dù test pass hay fail
      addTearDown(() async {
        await drawingBloc.close();
        await savedCubit.close();
        await mapCubit.close();
      });

      await tester.pumpWidget(
        createTestableWidget(
          drawingBloc: drawingBloc,
          savedRoutesCubit: savedCubit,
          mapDisplayCubit: mapCubit,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify top bar, toolbar, and bottom card are present
      expect(find.byType(RouteDrawingTopBar), findsOneWidget);
      expect(find.byType(RouteDrawingFloatingToolbar), findsOneWidget);
      expect(find.byType(RouteDrawingBottomCard), findsOneWidget);
      expect(find.byKey(const Key('mock_map_layer')), findsOneWidget);

      // Verify initial state
      expect(find.text('Chạm vào bản đồ để chọn điểm bắt đầu'), findsOneWidget);

      // Add a point via bloc
      drawingBloc.add(const RouteDrawingPointTapped(lat: 10.7, lon: 106.7));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Chạm điểm tiếp theo để tạo lộ trình'), findsOneWidget);

      // Add second point via bloc
      drawingBloc.add(const RouteDrawingPointTapped(lat: 10.8, lon: 106.8));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('1.5 km'), findsOneWidget);
      expect(find.byKey(const Key('route_drawing_save_button')), findsOneWidget);
      expect(find.byKey(const Key('route_drawing_navigate_button')), findsOneWidget);

      // Tap Undo
      await tester.tap(find.byKey(const Key('route_drawing_undo_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Chạm điểm tiếp theo để tạo lộ trình'), findsOneWidget);
    });
  });
}
