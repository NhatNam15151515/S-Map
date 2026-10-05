import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/generated/codegen_loader.g.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/search/search_screen.dart';
import 'package:s_map/screens/search/widgets/widgets.dart';

class _FakePoiRepository extends IPoiRepository {
  @override
  Future<List<PoiModel>> searchByName(String query, {int limit = 20}) async => [];

  @override
  Future<List<PoiModel>> searchByNameAscii(String query, {int limit = 20}) async => [];

  @override
  Future<List<PoiModel>> search(String query, {int limit = 20}) async => [
        const PoiModel(
          id: 101,
          name: 'Hồ Gươm',
          nameAscii: 'Ho Guom',
          lat: 21.0285,
          lon: 105.8542,
          category: 'tourism',
          address: 'Hoàn Kiếm, Hà Nội',
        ),
      ];

  @override
  Future<List<PoiModel>> searchInBounds({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    String? query,
    String? category,
    int limit = 50,
  }) async =>
      [];

  @override
  Future<List<String>> getSuggestions(String query, {int limit = 10}) async => [
        'Hồ Gươm',
      ];

  @override
  Future<PoiModel?> getPoiById(int id) async => null;
}

Widget createTestableWidget(Widget child) {
  final router = GoRouter(
    initialLocation: '/search',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('root')),
        routes: [
          GoRoute(
            path: 'search',
            builder: (context, state) => Scaffold(body: child),
          ),
        ],
      ),
    ],
  );
  return EasyLocalization(
    supportedLocales: const [Locale('vi'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('vi'),
    startLocale: const Locale('vi'),
    assetLoader: const CodegenLoader(),
    child: BlocProvider(
      create: (_) => AppCubit(),
      child: MaterialApp.router(
        routerConfig: router,
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

  group('SearchScreen & SearchScreenContent Integration Tests', () {
    testWidgets('SearchScreen renders with default params and NoOp services', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        const SearchScreen(
          userLocation: LatLng(21.0, 105.8),
          hasExistingDestinations: false,
          locationService: NoOpLocationService(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(SearchInputField), findsOneWidget);
      expect(find.byType(SearchCurrentLocationTile), findsOneWidget);
    });

    testWidgets('SearchScreenContent handles onAcquireLocation callback', (tester) async {
      bool acquired = false;
      final searchCubit = SearchCubit(
        poiRepository: _FakePoiRepository(),
        recentSearchService: NoOpRecentSearchService(),
      );

      await tester.pumpWidget(createTestableWidget(
        BlocProvider.value(
          value: searchCubit,
          child: SearchScreenContent(
            hasExistingDestinations: false,
            onAcquireLocation: () async {
              acquired = true;
              return const LatLng(21.03, 105.85);
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Tap acquire location from tile
      await tester.tap(find.byType(SearchCurrentLocationTile));
      await tester.pump();
      expect(acquired, isTrue);

      searchCubit.close();
    });

    testWidgets('SearchScreenContent passes hasExistingDestinations to SearchResultsList', (tester) async {
      final searchCubit = SearchCubit(
        poiRepository: _FakePoiRepository(),
        recentSearchService: NoOpRecentSearchService(),
        userLocation: const LatLng(21.0, 105.8),
      );

      await tester.pumpWidget(createTestableWidget(
        BlocProvider.value(
          value: searchCubit,
          child: const SearchScreenContent(
            hasExistingDestinations: true,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Trigger search query
      searchCubit.onQueryChanged('Hồ', debounceDuration: Duration.zero);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      // Should show the add destination button
      expect(find.byKey(const Key('poi_list_tile_add_destination_button')), findsOneWidget);

      searchCubit.close();
    });

    testWidgets('Enter returns the result list to the map workflow', (tester) async {
      final searchCubit = SearchCubit(
        poiRepository: _FakePoiRepository(),
        recentSearchService: NoOpRecentSearchService(),
        userLocation: const LatLng(21.0, 105.8),
      );

      await tester.pumpWidget(createTestableWidget(
        BlocProvider.value(
          value: searchCubit,
          child: const SearchScreenContent(
            hasExistingDestinations: true,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Hồ Gươm');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text('root'), findsOneWidget);
      searchCubit.close();
    });
  });
}
