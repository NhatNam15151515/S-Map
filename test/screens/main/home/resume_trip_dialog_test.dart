import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/generated/codegen_loader.g.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/main/home/widgets/navigation/resume_trip_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget createTestApp(Widget child) {
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
        home: Scaffold(
          body: Center(child: child),
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

  group('ResumeTripDialog Widget Tests', () {
    testWidgets('renders dialog with destination info and localized strings', (tester) async {
      await tester.pumpWidget(createTestApp(
        ResumeTripDialog(
          snapshot: sampleSnapshot,
          onResume: () {},
          onDiscard: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(ResumeTripDialog), findsOneWidget);
      expect(find.byIcon(Icons.restore_rounded), findsOneWidget);
      expect(find.text('Tiếp tục chuyến đi?'), findsOneWidget);
      expect(find.textContaining('Nhà Hát Thành Phố'), findsOneWidget);
      expect(find.text('Quãng đường'), findsOneWidget);
      expect(find.text('Thời gian'), findsOneWidget);
      expect(find.text('Tiếp tục'), findsOneWidget);
      expect(find.text('Bỏ qua'), findsOneWidget);
    });

    testWidgets('tapping resume button triggers onResume callback', (tester) async {
      bool resumed = false;

      await tester.pumpWidget(createTestApp(
        ResumeTripDialog(
          snapshot: sampleSnapshot,
          onResume: () {
            resumed = true;
          },
          onDiscard: () {},
        ),
      ));
      await tester.pumpAndSettle();

      final resumeBtn = find.widgetWithText(ElevatedButton, 'Tiếp tục');
      expect(resumeBtn, findsOneWidget);
      await tester.tap(resumeBtn);
      await tester.pumpAndSettle();

      expect(resumed, isTrue);
    });

    testWidgets('tapping discard button triggers onDiscard callback', (tester) async {
      bool discarded = false;

      await tester.pumpWidget(createTestApp(
        ResumeTripDialog(
          snapshot: sampleSnapshot,
          onResume: () {},
          onDiscard: () {
            discarded = true;
          },
        ),
      ));
      await tester.pumpAndSettle();

      final discardBtn = find.widgetWithText(OutlinedButton, 'Bỏ qua');
      expect(discardBtn, findsOneWidget);
      await tester.tap(discardBtn);
      await tester.pumpAndSettle();

      expect(discarded, isTrue);
    });
  });
}
