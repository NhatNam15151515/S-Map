import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/generated/codegen_loader.g.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/main/home/widgets/drawing/widgets.dart';
import 'package:s_map/screens/main/home/widgets/map/home_map_controls.dart';

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
  Future<List<RouteResult>> calculateAlternativeRoutes({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    String? vehicleProfile,
  }) async {
    final route = await calculateRoute(
      fromLat: fromLat,
      fromLon: fromLon,
      toLat: toLat,
      toLon: toLon,
      vehicleProfile: vehicleProfile,
    );
    return [route];
  }

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

/// Tạo widget testable cho Route Drawing UI — các widget production thật.
///
/// Test trực tiếp các widget con (WaypointPanel, BottomCard, FloatingToolbar, CrosshairOverlay)
/// vì trong production chúng được compose trực tiếp trong HomeScreenContent.
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
        home: MultiBlocProvider(
          providers: [
            BlocProvider<MapDisplayCubit>.value(value: mapDisplayCubit),
            BlocProvider<RouteDrawingBloc>.value(value: drawingBloc),
            BlocProvider<SavedRoutesCubit>.value(value: savedRoutesCubit),
          ],
          child: Scaffold(
            body: BlocBuilder<RouteDrawingBloc, RouteDrawingState>(
              builder: (context, state) {
                return Stack(
                  children: [
                    const SizedBox.expand(key: Key('mock_map_layer')),
                    HomeDrawingOverlay(
                      topPadding: 44.0,
                      drawingState: state,
                      drawingBloc: drawingBloc,
                      savedRoutesCubit: savedRoutesCubit,
                      isCrosshairActive: true,
                      onAddPointAtCenter: () {},
                      onOpenSearch: () {},
                      onExit: () {},
                      onDrawingPoiTap: (_) {},
                      onAddDestination: (_) {},
                      onCloseSearchResults: () {},
                      onClosePoiCard: () {},
                    ),
                    HomeMapControls(
                      displayCubit: mapDisplayCubit,
                      isDrawingMode: true,
                      canReverse: state.points.length >= 2,
                    ),
                  ],
                );
              },
            ),
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

  group('Route Drawing Widget Integration Tests', () {
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

      // Verify waypoint panel, toolbar, and bottom card are present
      expect(find.byType(RouteDrawingWaypointPanel), findsOneWidget);
      expect(find.byType(HomeMapControls), findsOneWidget);
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

      // Undo point
      drawingBloc.add(const RouteDrawingUndo());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Chạm điểm tiếp theo để tạo lộ trình'), findsOneWidget);
    });

    testWidgets(
        'undo on empty route does not crash and leaves points empty',
        (tester) async {
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
      await tester.pumpAndSettle();

      drawingBloc.add(const RouteDrawingUndo());
      await tester.pumpAndSettle();

      expect(drawingBloc.state.points, isEmpty);
    });

    testWidgets(
        'toggling crosshair mode shows or hides center add point button',
        (tester) async {
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

      addTearDown(() async {
        await drawingBloc.close();
        await savedCubit.close();
        await mapCubit.close();
      });

      // Dùng StatefulBuilder để quản lý toggle crosshair trong test
      bool isCrosshairActive = true;

      await tester.pumpWidget(
        EasyLocalization(
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
              home: MultiBlocProvider(
                providers: [
                  BlocProvider<MapDisplayCubit>.value(value: mapCubit),
                  BlocProvider<RouteDrawingBloc>.value(value: drawingBloc),
                  BlocProvider<SavedRoutesCubit>.value(value: savedCubit),
                ],
                child: Scaffold(
                  body: StatefulBuilder(
                    builder: (context, setLocalState) {
                      return BlocBuilder<RouteDrawingBloc, RouteDrawingState>(
                        builder: (context, state) {
                          return Stack(
                            children: [
                              const SizedBox.expand(key: Key('mock_map_layer')),
                              HomeDrawingOverlay(
                                topPadding: 44.0,
                                drawingState: state,
                                drawingBloc: drawingBloc,
                                savedRoutesCubit: savedCubit,
                                isCrosshairActive: isCrosshairActive,
                                onAddPointAtCenter: () {},
                                onOpenSearch: () {},
                                onExit: () {},
                                onDrawingPoiTap: (_) {},
                                onAddDestination: (_) {},
                                onCloseSearchResults: () {},
                                onClosePoiCard: () {},
                              ),
                              HomeMapControls(
                                displayCubit: mapCubit,
                                isDrawingMode: true,
                                                              isCrosshairActive: isCrosshairActive,
                                onToggleCrosshair: () {
                                  setLocalState(() {
                                    isCrosshairActive = !isCrosshairActive;
                                  });
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ban đầu: Crosshair active -> hiển thị nút thêm điểm tại tâm
      expect(find.byKey(const Key('route_drawing_add_point_center_btn')),
          findsOneWidget);

      // Nhấn nút crosshair trên toolbar: tắt crosshair -> ẩn nút thêm điểm tại tâm
      final crosshairBtn = find.byKey(const Key('route_drawing_crosshair_button'));
      await tester.ensureVisible(crosshairBtn);
      await tester.tap(crosshairBtn);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('route_drawing_add_point_center_btn')),
          findsNothing);

      // Bật lại crosshair
      await tester.ensureVisible(crosshairBtn);
      await tester.tap(crosshairBtn);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('route_drawing_add_point_center_btn')),
          findsOneWidget);
    });
  });
}
