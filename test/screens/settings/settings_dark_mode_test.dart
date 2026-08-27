import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/generated/codegen_loader.g.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/screens/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSharedPreferences implements ISharedPreferences {
  String? storedTheme;
  bool isFirst = false;

  @override
  Future<bool> get1stInstall() async => isFirst;

  @override
  Future<void> save1stInstall() async => isFirst = false;

  @override
  Future<String?> getThemeMode() async => storedTheme;

  @override
  Future<void> saveThemeMode(String mode) async {
    storedTheme = mode;
  }
}

Widget createSettingsTestApp({required AppCubit appCubit}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );

  return EasyLocalization(
    supportedLocales: const [Locale('vi'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('vi'),
    startLocale: const Locale('vi'),
    assetLoader: const CodegenLoader(),
    child: BlocProvider<AppCubit>.value(
      value: appCubit,
      child: Builder(
        builder: (context) => MaterialApp.router(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          routerConfig: router,
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

  group('SettingsScreen Dark Mode Widget Tests', () {
    testWidgets('SettingsScreen renders Dark Mode switch and toggles state',
        (tester) async {
      final fakePrefs = FakeSharedPreferences();
      final appCubit = AppCubit(sharedPreferences: fakePrefs);

      await tester.pumpWidget(createSettingsTestApp(appCubit: appCubit));
      await tester.pumpAndSettle();

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.value, isFalse);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(appCubit.state.themeMode, equals(ThemeMode.dark));
      expect(appCubit.state.isDarkMode, isTrue);

      final updatedSwitchWidget = tester.widget<Switch>(switchFinder);
      expect(updatedSwitchWidget.value, isTrue);

      appCubit.close();
    });

    testWidgets(
        'SettingsScreen opens ThemeMode selection dialog on tile tap and selects mode',
        (tester) async {
      final fakePrefs = FakeSharedPreferences();
      final appCubit = AppCubit(sharedPreferences: fakePrefs);

      await tester.pumpWidget(createSettingsTestApp(appCubit: appCubit));
      await tester.pumpAndSettle();

      final darkModeTileFinder = find.byIcon(Icons.dark_mode_rounded);
      expect(darkModeTileFinder, findsOneWidget);

      await tester.tap(darkModeTileFinder);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      final darkOptionFinder = find.byKey(const ValueKey('theme_option_dark'));
      expect(darkOptionFinder, findsOneWidget);

      await tester.tap(darkOptionFinder);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(appCubit.state.themeMode, equals(ThemeMode.dark));
      expect(appCubit.state.isDarkMode, isTrue);

      appCubit.close();
    });
  });
}
