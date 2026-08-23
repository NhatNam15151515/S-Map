import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/generated/codegen_loader.g.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/route_drawing/widgets/widgets.dart';

class MockCustomRouteRepository implements ICustomRouteRepository {
  List<CustomRouteModel> routes = [];

  @override
  Future<List<CustomRouteModel>> getSavedRoutes() async => List.from(routes);

  @override
  Future<CustomRouteModel?> getRouteById(String id) async {
    try {
      return routes.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveRoute(CustomRouteModel route) async {
    routes.add(route);
  }

  @override
  Future<void> deleteRoute(String id) async {
    routes.removeWhere((r) => r.id == id);
  }

  @override
  Future<void> clearAllRoutes() async {
    routes.clear();
  }

  @override
  Stream<List<CustomRouteModel>> watchSavedRoutes() async* {
    yield List.from(routes);
  }
}

Widget createTestableWidget({
  required Widget child,
  required SavedRoutesCubit cubit,
}) {
  return EasyLocalization(
    supportedLocales: const [Locale('vi'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('vi'),
    startLocale: const Locale('vi'),
    assetLoader: const CodegenLoader(),
    child: Builder(
      builder: (context) => BlocProvider<SavedRoutesCubit>.value(
        value: cubit,
        child: MaterialApp(
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
    EasyLocalization.logger.enableLevels = [];
  });

  group('SavedRoutesSheet Widget Tests', () {
    testWidgets('shows empty state when no saved routes exist', (tester) async {
      final mockRepo = MockCustomRouteRepository();
      final cubit = SavedRoutesCubit(
        customRouteRepository: mockRepo,
        autoInit: true,
        autoWatch: false,
      );

      await tester.pumpWidget(
        createTestableWidget(
          cubit: cubit,
          child: SavedRoutesSheet(
            onRouteSelected: (_) {},
            onRouteDeleted: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chưa có lộ trình nào được lưu'), findsOneWidget);
      await cubit.close();
    });

    testWidgets('lists saved routes and handles selection and deletion', (tester) async {
      final mockRepo = MockCustomRouteRepository();
      final customRoute = CustomRouteModel(
        id: 'route_1',
        name: 'Đường đi Vũng Tàu',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        waypoints: const [
          SnappedRoadPoint(
            isSnapped: true,
            originalLat: 10.7,
            originalLon: 106.7,
            snappedLat: 10.7,
            snappedLon: 106.7,
          ),
        ],
        fullPolyline: const [
          [10.7, 106.7],
          [10.8, 106.8],
        ],
        totalDistance: 12500,
        totalTime: 900000,
      );
      mockRepo.routes.add(customRoute);

      final cubit = SavedRoutesCubit(
        customRouteRepository: mockRepo,
        autoInit: true,
        autoWatch: false,
      );

      CustomRouteModel? selectedRoute;
      String? deletedId;

      await tester.pumpWidget(
        createTestableWidget(
          cubit: cubit,
          child: SavedRoutesSheet(
            onRouteSelected: (r) => selectedRoute = r,
            onRouteDeleted: (id) => deletedId = id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đường đi Vũng Tàu'), findsOneWidget);
      expect(find.text('12.5 km • 1 điểm mốc'), findsOneWidget);

      // Select route
      await tester.tap(find.text('Đường đi Vũng Tàu'));
      await tester.pump();
      expect(selectedRoute?.id, 'route_1');

      // Delete route: tap trash icon by key -> confirm dialog
      await tester.tap(find.byKey(const Key('delete_saved_route_route_1')));
      await tester.pumpAndSettle();

      expect(find.text('Xóa lộ trình đã lưu?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('delete_saved_route_confirm_btn')));
      await tester.pumpAndSettle();

      expect(deletedId, 'route_1');
      await cubit.close();
    });
  });
}
