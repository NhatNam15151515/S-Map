import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/widgets/app_button.dart';
import 'package:s_map/commons/widgets/download_progress_view.dart';

Widget createTestApp(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    minTextAdapt: true,
    splitScreenMode: true,
    builder: (_, __) => MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DownloadProgressView Reusable Dumb Widget Tests', () {
    testWidgets('renders title, itemName, progressText, and cancel button', (
      tester,
    ) async {
      bool cancelled = false;

      await tester.pumpWidget(
        createTestApp(
          DownloadProgressView(
            title: 'Đang tải bản đồ...',
            itemName: 'Hà Nội & Miền Bắc',
            progress: 0.5,
            progressText: '50.0% (25.0 MB / 50.0 MB)',
            cancelLabel: 'Hủy tải',
            onCancel: () => cancelled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đang tải bản đồ...'), findsOneWidget);
      expect(find.text('Hà Nội & Miền Bắc'), findsOneWidget);
      expect(find.text('50.0% (25.0 MB / 50.0 MB)'), findsOneWidget);
      expect(find.text('Hủy tải'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      await tester.tap(find.byType(AppButton));
      expect(cancelled, isTrue);
    });

    testWidgets('clamps NaN and out-of-range progress safely without crash', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          const DownloadProgressView(
            itemName: 'TP. Hồ Chí Minh',
            progress: double.nan,
            progressText: '0.0%',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, equals(0.0));
      expect(find.byType(AppButton), findsNothing);
    });

    testWidgets('supports custom icon and color theme overrides', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          const DownloadProgressView(
            itemName: 'Gói giọng nói dẫn đường',
            progress: 0.8,
            progressText: '80.0%',
            icon: Icons.record_voice_over_rounded,
            foregroundColor: Colors.purple,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.record_voice_over_rounded), findsOneWidget);
      final iconWidget = tester.widget<Icon>(
        find.byIcon(Icons.record_voice_over_rounded),
      );
      expect(iconWidget.color, equals(Colors.purple));
    });
  });
}
