import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s_map/generated/codegen_loader.g.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/route_drawing/widgets/widgets.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('RouteDrawingWaypointPanel Widget Tests', () {
    final points = [
      const SnappedRoadPoint(
        isSnapped: true,
        originalLat: 10.7626,
        originalLon: 106.6601,
        snappedLat: 10.7626,
        snappedLon: 106.6601,
        streetName: 'Đường Nguyễn Trãi',
      ),
      const SnappedRoadPoint(
        isSnapped: true,
        originalLat: 10.7765,
        originalLon: 106.7009,
        snappedLat: 10.7765,
        snappedLon: 106.7009,
        streetName: 'Đường Lê Lợi',
      ),
      const SnappedRoadPoint(
        isSnapped: true,
        originalLat: 10.7800,
        originalLon: 106.7050,
        snappedLat: 10.7800,
        snappedLon: 106.7050,
        streetName: 'Đường Đồng Khởi',
      ),
    ];

    final segments = [
      const RouteResult(
        isSuccess: true,
        distance: 1000,
        time: 60000,
        points: [
          [10.7626, 106.6601],
          [10.7765, 106.7009],
        ],
        isStraightLine: false,
      ),
      const RouteResult(
        isSuccess: true,
        distance: 500,
        time: 30000,
        points: [
          [10.7765, 106.7009],
          [10.7800, 106.7050],
        ],
        isStraightLine: true,
      ),
    ];

    testWidgets('renders Google Maps waypoint card with airplane toggles and add button',
        (tester) async {
      int? toggledSegment;
      int? removedIndex;
      bool searchPressed = false;

      await tester.pumpWidget(
        EasyLocalization(
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
                body: Stack(
                  children: [
                    RouteDrawingWaypointPanel(
                      topPadding: 20,
                      points: points,
                      segments: segments,
                      onSavedRoutesPressed: () {},
                      onSearchDestinationPressed: () {
                        searchPressed = true;
                      },
                      onReorder: (oldIdx, newIdx) {},
                      onRemovePoint: (idx) {
                        removedIndex = idx;
                      },
                      onToggleSegmentStraightLine: (segIdx) {
                        toggledSegment = segIdx;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Kiểm tra nút Back tròn nổi
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      // 2. Hiển thị danh sách các điểm rõ ràng
      expect(find.text('Đường Nguyễn Trãi'), findsOneWidget);
      expect(find.text('Đường Lê Lợi'), findsOneWidget);
      expect(find.text('Đường Đồng Khởi'), findsOneWidget);

      // 3. Hiển thị nút toggle đường thẳng (line) cho 2 segment
      final lineToggles = find.byIcon(Icons.linear_scale_rounded);
      expect(lineToggles, findsNWidgets(2));

      // Tap nút toggle đường thẳng đầu tiên (segment 0)
      await tester.tap(lineToggles.first);
      expect(toggledSegment, 0);

      // 4. Tap nút xóa điểm thứ hai (index 1)
      final deleteTooltip =
          tr(LocaleKeys.route_drawing_ui_delete_waypoint_tooltip);
      final deleteButtons = find.byTooltip(deleteTooltip);
      expect(deleteButtons, findsNWidgets(2));
      await tester.tap(deleteButtons.first);
      expect(removedIndex, 1);

      // 5. Tap nút "+" thêm điểm đến ở đáy card (theo khoanh đỏ của user)
      final addDestText = tr(LocaleKeys.route_drawing_ui_add_destination);
      await tester.tap(find.text(addDestText));
      expect(searchPressed, isTrue);
    });
  });
}
