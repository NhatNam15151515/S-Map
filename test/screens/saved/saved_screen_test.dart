import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/generated/codegen_loader.g.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/main/saved/saved_screen.dart';
import 'package:s_map/screens/main/saved/widgets/widgets.dart';

Widget createTestableWidget({
  required Widget child,
  required FavoritesCubit favoritesCubit,
}) {
  return EasyLocalization(
    supportedLocales: const [Locale('vi'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('vi'),
    startLocale: const Locale('vi'),
    assetLoader: const CodegenLoader(),
    child: MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AppCubit()),
        BlocProvider.value(value: favoritesCubit),
      ],
      child: MaterialApp(
        home: child,
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

  const samplePoi = PoiModel(
    id: 1,
    name: 'Phở Thìn Bờ Hồ',
    nameAscii: 'Pho Thin Bo Ho',
    category: 'food',
    lat: 21.03,
    lon: 105.85,
    address: '61 Đinh Tiên Hoàng',
  );

  group('SavedScreen Widget Tests', () {
    testWidgets('renders empty state when favorites list is empty',
        (tester) async {
      final mockService = NoOpFavoritesService();
      final favCubit = FavoritesCubit(favoritesService: mockService);

      await tester.pumpWidget(createTestableWidget(
        child: const SavedScreen(),
        favoritesCubit: favCubit,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(SavedScreen), findsOneWidget);
      expect(find.byType(SavedScreenContent), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);

      await favCubit.close();
    });

    testWidgets('renders saved POI cards and handles removal', (tester) async {
      final mockService = NoOpFavoritesService();
      final favCubit = FavoritesCubit(favoritesService: mockService);
      await favCubit.toggleFavorite(samplePoi);

      await tester.pumpWidget(createTestableWidget(
        child: const SavedScreen(),
        favoritesCubit: favCubit,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(SavedPoiCard), findsOneWidget);
      expect(find.text('Phở Thìn Bờ Hồ'), findsOneWidget);
      expect(find.text('61 Đinh Tiên Hoàng'), findsOneWidget);
      expect(find.byIcon(Icons.directions_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_remove_rounded), findsOneWidget);

      // Tap remove button
      await tester.tap(find.byIcon(Icons.bookmark_remove_rounded));
      await tester.pumpAndSettle();

      expect(favCubit.state.favorites, isEmpty);
      expect(find.byType(SavedPoiCard), findsNothing);
      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);

      await favCubit.close();
    });
  });
}
