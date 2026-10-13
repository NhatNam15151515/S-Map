import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/widgets/empty_widget.dart';
import 'package:s_map/commons/widgets/region_card.dart';
import 'package:s_map/generated/codegen_loader.g.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/settings/offline_regions/offline_regions_screen.dart';
import 'package:s_map/screens/settings/offline_regions/widgets/offline_storage_summary_card.dart';

class FakeDownloadRegionCubit extends Cubit<DownloadRegionState>
    implements DownloadRegionCubit {
  FakeDownloadRegionCubit(super.initialState);

  @override
  Future<void> loadRegions({bool checkUpdates = false}) async {}

  @override
  Future<void> checkForUpdates() async {}

  @override
  Future<void> downloadRegion(String regionId) async {}

  @override
  Future<void> deleteRegion(String regionId) async {}

  @override
  Future<void> cancelDownload(String regionId) async {}
}

Widget createTestApp({
  required DownloadRegionCubit cubit,
  required Widget child,
}) {
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
          home: BlocProvider<DownloadRegionCubit>.value(
            value: cubit,
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('OfflineRegionsContent Tests', () {
    testWidgets('renders EmptyWidget when regions list is empty', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeCubit = FakeDownloadRegionCubit(
        const DownloadRegionState(
          status: DownloadRegionStatus.loaded,
          regions: [],
          totalStorageBytes: 0,
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          cubit: fakeCubit,
          child: const OfflineRegionsContent(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OfflineStorageSummaryCard), findsOneWidget);
      expect(find.byType(EmptyWidget), findsOneWidget);
      expect(find.byType(RegionCard), findsNothing);
    });

    testWidgets('renders RegionCard list when regions are present', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const sampleRegion = RegionModel(
        id: 'hanoi',
        name: 'Hà Nội & Miền Bắc',
        description: 'Bản đồ ngoại tuyến',
        downloadUrl: 'https://example.com/hanoi.tar.gz',
        sizeBytes: 50 * 1024 * 1024,
        version: '1.0.0',
        status: RegionDownloadStatus.notDownloaded,
        downloadProgress: 0.0,
        bbox: [20.5, 105.0, 21.5, 106.0],
      );

      final fakeCubit = FakeDownloadRegionCubit(
        const DownloadRegionState(
          status: DownloadRegionStatus.loaded,
          regions: [sampleRegion],
          totalStorageBytes: 50 * 1024 * 1024,
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          cubit: fakeCubit,
          child: const OfflineRegionsContent(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OfflineStorageSummaryCard), findsOneWidget);
      expect(find.byType(RegionCard), findsOneWidget);
      expect(find.byType(EmptyWidget), findsNothing);
      expect(find.text('Hà Nội & Miền Bắc'), findsOneWidget);
    });
  });
}
