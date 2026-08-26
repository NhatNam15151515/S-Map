import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/main/home/widgets/navigation/resume_trip_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sampleRoute = RouteResult(
    isSuccess: true,
    distance: 2500.0,
    time: 300000,
    points: [
      [10.7769, 106.7009],
      [10.7820, 106.7050],
    ],
    instructions: [
      RouteInstruction(
        text: 'Đi thẳng trên Lê Lợi',
        streetName: 'Lê Lợi',
        distance: 1000.0,
        time: 120000,
        sign: 0,
        points: [
          [10.7769, 106.7009],
          [10.7820, 106.7050],
        ],
      ),
    ],
  );

  final sampleSnapshot = ActiveTripSnapshot(
    origin: const RoutePoint(lat: 10.7769, lon: 106.7009),
    destination: const RoutePoint(lat: 10.7820, lon: 106.7050),
    destinationName: 'Nhà Hát Thành Phố',
    profile: RoutingConstants.profileMopedVn,
    initialRoute: sampleRoute,
    currentSegmentIndex: 0,
    currentInstructionIndex: 0,
    tripStartTime: DateTime.now().subtract(const Duration(minutes: 5)),
    lastSavedTime: DateTime.now(),
    totalDistanceTraveledMeters: 1200.0,
    maxSpeedKmh: 38.0,
    speedSampleSum: 500.0,
    speedSampleCount: 15,
  );

  Widget createTestWidget({
    required ActiveTripSnapshot snapshot,
    required VoidCallback onResume,
    required VoidCallback onDiscard,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ResumeTripDialog(
          snapshot: snapshot,
          onResume: onResume,
          onDiscard: onDiscard,
        ),
      ),
    );
  }

  group('ResumeTripDialog Widget Tests', () {
    testWidgets('renders dialog with destination info and action buttons', (tester) async {
      await tester.pumpWidget(createTestWidget(
        snapshot: sampleSnapshot,
        onResume: () {},
        onDiscard: () {},
      ));
      await tester.pumpAndSettle();

      expect(find.byType(ResumeTripDialog), findsOneWidget);
      expect(find.byIcon(Icons.restore_rounded), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('tapping resume button triggers onResume callback', (tester) async {
      bool resumed = false;

      await tester.pumpWidget(createTestWidget(
        snapshot: sampleSnapshot,
        onResume: () {
          resumed = true;
        },
        onDiscard: () {},
      ));
      await tester.pumpAndSettle();

      final resumeBtn = find.byType(ElevatedButton);
      expect(resumeBtn, findsOneWidget);
      await tester.tap(resumeBtn);
      await tester.pumpAndSettle();

      expect(resumed, isTrue);
    });

    testWidgets('tapping discard button triggers onDiscard callback', (tester) async {
      bool discarded = false;

      await tester.pumpWidget(createTestWidget(
        snapshot: sampleSnapshot,
        onResume: () {},
        onDiscard: () {
          discarded = true;
        },
      ));
      await tester.pumpAndSettle();

      final discardBtn = find.byType(OutlinedButton);
      expect(discardBtn, findsOneWidget);
      await tester.tap(discardBtn);
      await tester.pumpAndSettle();

      expect(discarded, isTrue);
    });
  });
}
