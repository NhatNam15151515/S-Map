import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s_map/commons/widgets/app_button.dart';
import 'package:s_map/commons/widgets/empty_widget.dart';
import 'package:s_map/commons/widgets/region_card.dart';
import 'package:s_map/generated/codegen_loader.g.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/onboarding/widgets/onboarding_downloading_view.dart';
import 'package:s_map/screens/onboarding/widgets/onboarding_region_picker_view.dart';

Widget createTestApp(Widget child) {
  return EasyLocalization(
    supportedLocales: const [Locale('vi'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('vi'),
    startLocale: const Locale('vi'),
    assetLoader: const CodegenLoader(),
    child: Builder(
      builder: (context) => ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (_, __) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: Scaffold(body: child),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<RegionModel> sampleRegions = [
    const RegionModel(
      id: 'hanoi',
      name: 'Hà Nội & Miền Bắc',
      description: 'Bản đồ ngoại tuyến Hà Nội',
      downloadUrl: 'https://example.com/hanoi.tar.gz',
      sizeBytes: 50 * 1024 * 1024,
      version: '1.0.0',
      status: RegionDownloadStatus.notDownloaded,
      downloadProgress: 0.0,
      bbox: [20.5, 105.0, 21.5, 106.0],
    ),
  ];

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('OnboardingDownloadingView Pure Dumb Widget Tests', () {
    testWidgets('renders region info, progress text and triggers onCancel', (
      tester,
    ) async {
      bool cancelled = false;

      await tester.pumpWidget(
        createTestApp(
          OnboardingDownloadingView(
            regionName: 'Hà Nội & Miền Bắc',
            progress: 0.45,
            progressText: '45.0% (22.5 MB / 50 MB)',
            onCancel: () => cancelled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hà Nội & Miền Bắc'), findsOneWidget);
      expect(find.text('45.0% (22.5 MB / 50 MB)'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      await tester.tap(find.byType(AppButton));
      expect(cancelled, isTrue);
    });
  });

  group('OnboardingRegionPickerView Pure Dumb Widget Tests', () {
    testWidgets('renders RegionCard list when regions are available', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool downloaded = false;

      await tester.pumpWidget(
        createTestApp(
          OnboardingRegionPickerView(
            regions: sampleRegions,
            isLoading: false,
            hasError: false,
            onSkip: () {},
            onRetry: () {},
            onDownload: (_) => downloaded = true,
            onDelete: (_) {},
            onCancel: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RegionCard), findsOneWidget);
      expect(find.text('Hà Nội & Miền Bắc'), findsOneWidget);

      await tester.tap(find.byType(ElevatedButton));
      expect(downloaded, isTrue);
    });

    testWidgets('renders EmptyWidget when regions list is empty', (
      tester,
    ) async {
      bool retried = false;

      await tester.pumpWidget(
        createTestApp(
          OnboardingRegionPickerView(
            regions: const [],
            isLoading: false,
            hasError: true,
            hasDownloadedRegions: false,
            onSkip: () {},
            onRetry: () => retried = true,
            onDownload: (_) {},
            onDelete: (_) {},
            onCancel: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EmptyWidget), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);

      // Bấm nút thử lại
      await tester.tap(find.byType(OutlinedButton));
      expect(retried, isTrue);
    });
  });
}
