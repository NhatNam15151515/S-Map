import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/codegen_loader.g.dart';
import 'package:s_map/models/models.dart';

Widget createTestableWidget(Widget child, {FavoritesCubit? favoritesCubit}) {
  return EasyLocalization(
    supportedLocales: const [Locale('vi'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('vi'),
    startLocale: const Locale('vi'),
    assetLoader: const CodegenLoader(),
    child: MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AppCubit()),
        BlocProvider(create: (_) => MapDisplayCubit()),
        BlocProvider(create: (_) => favoritesCubit ?? FavoritesCubit()),
      ],
      child: MaterialApp(
        home: Scaffold(body: Center(child: child)),
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
    name: 'Phở Gia Truyền',
    nameAscii: 'Pho Gia Truyen',
    category: 'food',
    lat: 21.03,
    lon: 105.84,
    address: '49 Bát Đàn, Hoàn Kiếm',
  );

  group('PoiQuickCard Widget Tests', () {
    testWidgets('renders POI details, handles bookmark toggle and close action',
        (tester) async {
      bool closed = false;
      bool directionsTapped = false;
      final favService = NoOpFavoritesService();
      final favCubit = FavoritesCubit(favoritesService: favService);

      await tester.pumpWidget(createTestableWidget(
        PoiQuickCard(
          poi: samplePoi,
          onClose: () => closed = true,
          onDirections: () => directionsTapped = true,
        ),
        favoritesCubit: favCubit,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Phở Gia Truyền'), findsOneWidget);
      expect(find.text('49 Bát Đàn, Hoàn Kiếm'), findsOneWidget);
      expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);
      expect(find.byIcon(Icons.directions_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_outline_rounded), findsOneWidget);

      // Tap Bookmark
      await tester.tap(find.byIcon(Icons.bookmark_outline_rounded));
      await tester.pumpAndSettle();
      expect(favCubit.state.isFavorite('id:1'), isTrue);
      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);

      // Tap directions
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(directionsTapped, isTrue);

      // Tap close
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(closed, isTrue);
    });
  });
}
