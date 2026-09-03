import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/codegen_loader.g.dart';
import 'package:s_map/models/models.dart';

class MockLocationService implements ILocationService {
  LatLng? current;

  @override
  Position get position {
    final pos = current ?? const LatLng(21.0300, 105.8400);
    return Position(
      latitude: pos.latitude,
      longitude: pos.longitude,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );
  }

  @override
  (double, double) get latLng {
    final pos = current ?? const LatLng(21.0300, 105.8400);
    return (pos.latitude, pos.longitude);
  }

  @override
  Stream<Position> get positionStream => const Stream.empty();

  @override
  Future<Position> getCurrentPosition() async => position;

  @override
  Future<Position?> getLastKnownPosition() async => current != null ? position : null;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async => LocationPermission.always;

  @override
  Future<LocationPermission> requestPermission() async => LocationPermission.always;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Stream<Position> getPositionStream({
    LocationAccuracy accuracy = LocationAccuracy.bestForNavigation,
    int distanceFilter = 0,
    Duration? intervalDuration,
    bool enableBackground = false,
    String? notificationTitle,
    String? notificationText,
    bool enableWakeLock = true,
  }) =>
      const Stream.empty();

  @override
  Future<bool> isBatteryOptimizationIgnored() async => true;

  @override
  Future<bool> requestIgnoreBatteryOptimization() async => true;

  @override
  Future<bool> requestNotificationPermission() async => true;
}

Widget createTestableWidget(
  Widget child, {
  FavoritesCubit? favoritesCubit,
  MapDisplayCubit? mapDisplayCubit,
}) {
  return EasyLocalization(
    supportedLocales: const [Locale('vi'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('vi'),
    startLocale: const Locale('vi'),
    assetLoader: const CodegenLoader(),
    child: MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AppCubit()),
        if (mapDisplayCubit != null)
          BlocProvider.value(value: mapDisplayCubit)
        else
          BlocProvider(create: (_) => MapDisplayCubit()),
        BlocProvider(create: (_) => favoritesCubit ?? FavoritesCubit()),
      ],
      child: MaterialApp(
        home: Scaffold(body: Center(child: child)),
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

  const samplePoi = PoiModel(
    id: 1,
    name: 'Phở Gia Truyền',
    nameAscii: 'Pho Gia Truyen',
    category: 'food',
    lat: 21.0300,
    lon: 105.8400,
    address: '49 Bát Đàn, Hoàn Kiếm',
  );

  group('PoiQuickCard Widget Tests', () {
    testWidgets('renders POI details, handles bookmark toggle and close action',
        (tester) async {
      bool closed = false;
      bool directionsTapped = false;
      final favService = NoOpFavoritesService();
      final favCubit = FavoritesCubit(favoritesService: favService);

      await tester.pumpWidget(createTestableWidget(
        PoiQuickCard(
          poi: samplePoi,
          onClose: () => closed = true,
          onDirections: () => directionsTapped = true,
        ),
        favoritesCubit: favCubit,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Phở Gia Truyền'), findsOneWidget);
      expect(find.text('49 Bát Đàn, Hoàn Kiếm'), findsOneWidget);
      expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);
      expect(find.byIcon(Icons.directions_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_outline_rounded), findsOneWidget);

      // Tap Bookmark
      await tester.tap(find.byIcon(Icons.bookmark_outline_rounded));
      await tester.pumpAndSettle();
      expect(favCubit.state.isFavorite('id:1'), isTrue);
      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);

      // Tap directions
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(directionsTapped, isTrue);

      // Tap close
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(closed, isTrue);
    });

    testWidgets('rebuilds with calculated distance when user GPS location updates',
        (tester) async {
      final mockLocation = MockLocationService();
      final mapDisplayCubit = MapDisplayCubit(locationService: mockLocation);

      await tester.pumpWidget(createTestableWidget(
        PoiQuickCard(
          poi: samplePoi,
          onClose: () {},
        ),
        mapDisplayCubit: mapDisplayCubit,
      ));
      await tester.pumpAndSettle();

      // Initially, no GPS position set -> subtitle is only address
      expect(find.text('49 Bát Đàn, Hoàn Kiếm'), findsOneWidget);

      // User location updates nearby (approx 700m away in Hoàn Kiếm, Hà Nội)
      mockLocation.current = const LatLng(21.0350, 105.8450);
      await mapDisplayCubit.locateMe();
      await tester.pumpAndSettle();

      // Subtitle now contains distance prefix
      expect(find.textContaining('49 Bát Đàn, Hoàn Kiếm'), findsOneWidget);
      expect(find.textContaining('m •'), findsOneWidget);
    });
  });
}
