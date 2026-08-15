import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/screens/main/home/widgets/home_search_bar.dart';

void main() {
  group('HomeSearchBar Widget Tests', () {
    testWidgets('Renders search placeholder and search icon when showBackButton is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HomeSearchBar(showBackButton: false),
          ),
        ),
      );

      expect(find.text('Tìm kiếm ở đây'), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    });

    testWidgets('Renders back button when showBackButton is true', (tester) async {
      bool backPressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeSearchBar(
              showBackButton: true,
              onBackPressed: () {
                backPressed = true;
              },
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsNothing);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(backPressed, true);
    });
  });
}
