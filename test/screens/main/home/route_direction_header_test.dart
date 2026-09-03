import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/generated/codegen_loader.g.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/main/home/widgets/widgets.dart';

class FakeRoutingRepository implements IRoutingRepository {
  int calculateRouteCalls = 0;
  String? lastProfile;

  @override
  Future<RouteResult> calculateRoute({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    String? vehicleProfile,
  }) async {
    calculateRouteCalls++;
    lastProfile = vehicleProfile;
    return const RouteResult(
      isSuccess: true,
      distance: 3500.0,
      time: 420000,
      points: [
        [10.7769, 106.7009],
        [10.8231, 106.6297],
      ],
    );
  }

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

Widget createTestableWidget(Widget child, {required RoutePreviewCubit cubit}) {
  return EasyLocalization(
    supportedLocales: const [Locale('vi'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('vi'),
    startLocale: const Locale('vi'),
    assetLoader: const CodegenLoader(),
    child: Builder(
      builder: (context) => BlocProvider.value(
        value: cubit,
        child: MaterialApp(
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
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('RouteDirectionHeader Widget Tests', () {
    late FakeRoutingRepository fakeRepo;
    late RoutePreviewCubit cubit;

    setUp(() {
      fakeRepo = FakeRoutingRepository();
      cubit = RoutePreviewCubit(routingRepository: fakeRepo);
    });

    tearDown(() {
      cubit.close();
    });

    testWidgets('renders origin and destination labels and handles taps',
        (tester) async {
      await cubit.previewRouteBetweenPoints(
        origin: const RoutePoint(lat: 10.7769, lon: 106.7009),
        destination: const RoutePoint(lat: 10.8231, lon: 106.6297),
        originName: 'Nhà thờ Đức Bà',
        destinationName: 'Sân bay Tân Sơn Nhất',
      );

      bool onSelectOriginCalled = false;
      bool onSelectDestinationCalled = false;
      bool onCloseCalled = false;

      await tester.pumpWidget(
        createTestableWidget(
          RouteDirectionHeader(
            topPadding: 40,
            onSelectOrigin: () => onSelectOriginCalled = true,
            onSelectDestination: () => onSelectDestinationCalled = true,
            onClose: () => onCloseCalled = true,
          ),
          cubit: cubit,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nhà thờ Đức Bà'), findsOneWidget);
      expect(find.text('Sân bay Tân Sơn Nhất'), findsOneWidget);
      expect(find.text('Xe máy'), findsOneWidget);
      expect(find.text('Ô tô'), findsOneWidget);
      expect(find.text('Đi bộ'), findsOneWidget);

      // Tap Origin Box
      await tester.tap(find.text('Nhà thờ Đức Bà'));
      expect(onSelectOriginCalled, isTrue);

      // Tap Destination Box
      await tester.tap(find.text('Sân bay Tân Sơn Nhất'));
      expect(onSelectDestinationCalled, isTrue);

      // Tap Close button
      await tester.tap(find.byKey(const Key('route_direction_back_btn')));
      expect(onCloseCalled, isTrue);
    });

    testWidgets('swapping endpoints flips origin and destination',
        (tester) async {
      await cubit.previewRouteBetweenPoints(
        origin: const RoutePoint(lat: 10.7769, lon: 106.7009),
        destination: const RoutePoint(lat: 10.8231, lon: 106.6297),
        originName: 'Điểm A',
        destinationName: 'Điểm B',
      );

      await tester.pumpWidget(
        createTestableWidget(
          RouteDirectionHeader(
            topPadding: 40,
            onSelectOrigin: () {},
            onSelectDestination: () {},
            onClose: () {},
          ),
          cubit: cubit,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Điểm A'), findsOneWidget);
      expect(find.text('Điểm B'), findsOneWidget);

      // Tap Swap button
      await tester.tap(find.byKey(const Key('route_direction_swap_btn')));
      await tester.pumpAndSettle();

      expect(cubit.state.originName, equals('Điểm B'));
      expect(cubit.state.destinationName, equals('Điểm A'));
      expect(find.text('Điểm B'), findsOneWidget);
      expect(find.text('Điểm A'), findsOneWidget);
    });

    testWidgets('switching vehicle profile recalculates route with selected profile',
        (tester) async {
      await cubit.previewRouteBetweenPoints(
        origin: const RoutePoint(lat: 10.7769, lon: 106.7009),
        destination: const RoutePoint(lat: 10.8231, lon: 106.6297),
        originName: 'Điểm A',
        destinationName: 'Điểm B',
      );

      await tester.pumpWidget(
        createTestableWidget(
          RouteDirectionHeader(
            topPadding: 40,
            onSelectOrigin: () {},
            onSelectDestination: () {},
            onClose: () {},
          ),
          cubit: cubit,
        ),
      );
      await tester.pumpAndSettle();

      // Tap Ô tô
      await tester.tap(find.text('Ô tô'));
      await tester.pumpAndSettle();

      expect(cubit.state.profile, equals(RoutingConstants.profileCar));
      expect(fakeRepo.lastProfile, equals(RoutingConstants.profileCar));
    });

    testWidgets('renders localized my_location when originName is null',
        (tester) async {
      await cubit.previewRouteBetweenPoints(
        origin: const RoutePoint(lat: 10.7769, lon: 106.7009),
        destination: const RoutePoint(lat: 10.8231, lon: 106.6297),
        originName: null,
        destinationName: 'Sân bay Tân Sơn Nhất',
      );

      await tester.pumpWidget(
        createTestableWidget(
          RouteDirectionHeader(
            topPadding: 40,
            onSelectOrigin: () {},
            onSelectDestination: () {},
            onClose: () {},
          ),
          cubit: cubit,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vị trí của bạn'), findsOneWidget);
      expect(find.text('Sân bay Tân Sơn Nhất'), findsOneWidget);
    });
  });
}
