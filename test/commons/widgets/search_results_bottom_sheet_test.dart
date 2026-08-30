import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/codegen_loader.g.dart';
import 'package:s_map/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  const testPois = [
    PoiModel(
      id: 1,
      name: 'Chợ Bến Thành',
      nameAscii: 'Cho Ben Thanh',
      lat: 10.7725,
      lon: 106.6980,
      category: 'market',
      address: 'Quận 1, TP.HCM',
    ),
    PoiModel(
      id: 2,
      name: 'Nhà thờ Đức Bà',
      nameAscii: 'Nha tho Duc Ba',
      lat: 10.7798,
      lon: 106.6990,
      category: 'church',
      address: 'Công xã Paris, Quận 1, TP.HCM',
    ),
  ];

  Widget buildTestWidget({
    required List<PoiModel> pois,
    String? query,
    ValueChanged<PoiModel>? onPoiTap,
    VoidCallback? onClose,
    MapDisplayCubit? mapDisplayCubit,
  }) {
    return EasyLocalization(
      supportedLocales: const [Locale('vi'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('vi'),
      assetLoader: const CodegenLoader(),
      child: BlocProvider<MapDisplayCubit>.value(
        value: mapDisplayCubit ??
            MapDisplayCubit(
              locationService: const NoOpLocationService(),
            ),
        child: MaterialApp(
          home: Scaffold(
            body: SearchResultsBottomSheet(
              controller: DraggableScrollableController(),
              pois: pois,
              query: query,
              onPoiTap: onPoiTap,
              onClose: onClose,
            ),
          ),
        ),
      ),
    );
  }

  group('SearchResultsBottomSheet Widget Tests', () {
    testWidgets('renders search query, count and all POI items',
        (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          pois: testPois,
          query: 'Quận 1',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quận 1'), findsOneWidget);
      expect(find.text('Chợ Bến Thành'), findsOneWidget);
      expect(find.text('Nhà thờ Đức Bà'), findsOneWidget);
    });

    testWidgets('triggers onPoiTap when a POI is clicked', (tester) async {
      PoiModel? selected;
      await tester.pumpWidget(
        buildTestWidget(
          pois: testPois,
          query: 'Quận 1',
          onPoiTap: (poi) => selected = poi,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chợ Bến Thành'));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!.name, equals('Chợ Bến Thành'));
    });

    testWidgets('triggers onClose when close button is tapped', (tester) async {
      bool closed = false;
      await tester.pumpWidget(
        buildTestWidget(
          pois: testPois,
          query: 'Quận 1',
          onClose: () => closed = true,
        ),
      );
      await tester.pumpAndSettle();

      final closeButton = find.byIcon(Icons.close_rounded);
      expect(closeButton, findsOneWidget);

      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(closed, isTrue);
    });
  });
}
