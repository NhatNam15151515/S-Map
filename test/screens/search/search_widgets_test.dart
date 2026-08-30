import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/codegen_loader.g.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/search/widgets/widgets.dart';

Widget createTestableWidget(Widget child) {
  return EasyLocalization(
    supportedLocales: const [Locale('vi'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('vi'),
    startLocale: const Locale('vi'),
    assetLoader: const CodegenLoader(),
    child: BlocProvider(
      create: (_) => AppCubit(),
      child: MaterialApp(
        home: Scaffold(body: child),
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

  group('Search Widgets Tests', () {
    testWidgets('SearchInputField renders correctly and triggers callbacks', (tester) async {
      final controller = TextEditingController(text: 'Pho');
      String? changedQuery;
      String? submittedQuery;
      bool cleared = false;
      bool backPressed = false;

      await tester.pumpWidget(createTestableWidget(
        SearchInputField(
          controller: controller,
          onQueryChanged: (val) => changedQuery = val,
          onSubmitted: (val) => submittedQuery = val,
          onClear: () => cleared = true,
          onBackPressed: () => backPressed = true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Pho'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Type text
      await tester.enterText(find.byType(TextField), 'Bún chả');
      await tester.pump();
      expect(changedQuery, equals('Bún chả'));

      // Submit search
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(submittedQuery, equals('Bún chả'));

      // Tap clear
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(cleared, isTrue);

      // Tap back
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pump();
      expect(backPressed, isTrue);
    });

    testWidgets('SearchRecentList displays recent searches and handles deletion', (tester) async {
      final recents = ['Hồ Tây', 'Hồ Gươm'];
      String? tappedItem;
      String? removedItem;
      bool clearedAll = false;

      await tester.pumpWidget(createTestableWidget(
        Column(
          children: [
            Expanded(
              child: SearchRecentList(
                recentSearches: recents,
                onItemTap: (item) => tappedItem = item,
                onItemRemove: (item) => removedItem = item,
                onClearAll: () => clearedAll = true,
              ),
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Hồ Tây'), findsOneWidget);
      expect(find.text('Hồ Gươm'), findsOneWidget);

      // Tap item
      await tester.tap(find.text('Hồ Tây'));
      await tester.pump();
      expect(tappedItem, equals('Hồ Tây'));

      // Tap remove single item
      final closeIcons = find.byIcon(Icons.close_rounded);
      expect(closeIcons, findsNWidgets(2));
      await tester.tap(closeIcons.first);
      await tester.pump();
      expect(removedItem, equals('Hồ Tây'));

      // Tap clear all
      final clearAllButton = find.byType(TextButton);
      await tester.tap(clearAllButton);
      await tester.pump();
      expect(clearedAll, isTrue);
    });

    testWidgets('SearchRecentList displays empty view when recentSearches is empty', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        Column(
          children: [
            Expanded(
              child: SearchRecentList(
                recentSearches: const [],
                onItemTap: (_) {},
                onItemRemove: (_) {},
                onClearAll: () {},
              ),
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(EmptyWidget), findsOneWidget);
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    });

    testWidgets('SearchResultsList displays POI items and triggers onPoiTap', (tester) async {
      const samplePois = [
        PoiModel(
          id: 1,
          name: 'Phở Gia Truyền Bát Đàn',
          nameAscii: 'Pho Gia Truyen Bat Dan',
          category: 'food',
          lat: 21.033,
          lon: 105.845,
          address: '49 Bát Đàn, Hoàn Kiếm',
        ),
      ];

      PoiModel? selectedPoi;

      await tester.pumpWidget(createTestableWidget(
        SearchResultsList(
          results: samplePois,
          suggestions: const [],
          isLoading: false,
          onPoiTap: (poi) => selectedPoi = poi,
          onSuggestionTap: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Phở Gia Truyền Bát Đàn'), findsOneWidget);
      expect(find.text('49 Bát Đàn, Hoàn Kiếm'), findsOneWidget);
      expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);

      await tester.tap(find.text('Phở Gia Truyền Bát Đàn'));
      await tester.pump();
      expect(selectedPoi?.id, equals(1));
    });

    testWidgets('SearchResultsList displays distance prefix when userLocation is provided', (tester) async {
      const samplePois = [
        PoiModel(
          id: 1,
          name: 'Phở Gia Truyền Bát Đàn',
          nameAscii: 'Pho Gia Truyen Bat Dan',
          category: 'food',
          lat: 21.033,
          lon: 105.845,
          address: '49 Bát Đàn, Hoàn Kiếm',
        ),
      ];

      await tester.pumpWidget(createTestableWidget(
        SearchResultsList(
          results: samplePois,
          suggestions: const [],
          isLoading: false,
          userLocation: const LatLng(21.030, 105.840),
          onPoiTap: (_) {},
          onSuggestionTap: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('• 49 Bát Đàn, Hoàn Kiếm'), findsOneWidget);
    });

    testWidgets('SearchResultsList displays suggestions when no POIs are present', (tester) async {
      final suggestions = ['Cà phê trứng', 'Cà phê Giảng'];
      String? tappedSuggestion;

      await tester.pumpWidget(createTestableWidget(
        SearchResultsList(
          results: const [],
          suggestions: suggestions,
          isLoading: false,
          onPoiTap: (_) {},
          onSuggestionTap: (s) => tappedSuggestion = s,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Cà phê trứng'), findsOneWidget);
      expect(find.text('Cà phê Giảng'), findsOneWidget);

      await tester.tap(find.text('Cà phê Giảng'));
      await tester.pump();
      expect(tappedSuggestion, equals('Cà phê Giảng'));
    });

    testWidgets('SearchResultsList displays loading indicator when isLoading is true', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        SearchResultsList(
          results: const [],
          suggestions: const [],
          isLoading: true,
          onPoiTap: (_) {},
          onSuggestionTap: (_) {},
        ),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('SearchResultsList displays EmptyWidget when results and suggestions are empty', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        SearchResultsList(
          results: const [],
          suggestions: const [],
          isLoading: false,
          onPoiTap: (_) {},
          onSuggestionTap: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(EmptyWidget), findsOneWidget);
      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
    });
  });
}
