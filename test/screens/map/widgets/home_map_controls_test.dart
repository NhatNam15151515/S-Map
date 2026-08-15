import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/screens/main/home/widgets/home_map_controls.dart';

void main() {
  group('HomeMapControls Widget Tests', () {
    testWidgets('Renders all control buttons and triggers callbacks', (tester) async {
      bool zoomInTriggered = false;
      bool zoomOutTriggered = false;
      bool locateMeTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeMapControls(
              onZoomIn: () => zoomInTriggered = true,
              onZoomOut: () => zoomOutTriggered = true,
              onLocateMe: () => locateMeTriggered = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
      expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);
      expect(find.byIcon(Icons.layers_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add_rounded));
      expect(zoomInTriggered, true);

      await tester.tap(find.byIcon(Icons.remove_rounded));
      expect(zoomOutTriggered, true);

      await tester.tap(find.byIcon(Icons.my_location_rounded));
      expect(locateMeTriggered, true);
    });
  });
}
