import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/widgets/map_category_chips.dart';
import 'package:s_map/commons/widgets/map_controls.dart';
import 'package:s_map/commons/widgets/map_search_bar.dart';

void main() {
  group('Commons Map Widgets Tests', () {
    testWidgets('MapSearchBar renders correctly and handles back button', (tester) async {
      bool backPressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapSearchBar(
              showBackButton: true,
              onBackPressed: () => backPressed = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      expect(backPressed, true);
    });

    testWidgets('MapCategoryChips triggers onCategorySelected when chip tapped', (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapCategoryChips(
              onCategorySelected: (cat) => selected = cat,
            ),
          ),
        ),
      );

      expect(find.text('Ăn uống'), findsOneWidget);
      expect(find.text('Cà phê'), findsOneWidget);

      await tester.tap(find.text('Ăn uống'));
      await tester.pump();
      expect(selected, 'Ăn uống');
    });

    testWidgets('MapControls renders all action buttons and triggers callbacks', (tester) async {
      bool zoomIn = false;
      bool zoomOut = false;
      bool locateMe = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapControls(
              onZoomIn: () => zoomIn = true,
              onZoomOut: () => zoomOut = true,
              onLocateMe: () => locateMe = true,
              locateHeroTag: 'test_locate_fab',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
      expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add_rounded));
      expect(zoomIn, true);

      await tester.tap(find.byIcon(Icons.remove_rounded));
      expect(zoomOut, true);

      await tester.tap(find.byIcon(Icons.my_location_rounded));
      expect(locateMe, true);
    });
  });
}
