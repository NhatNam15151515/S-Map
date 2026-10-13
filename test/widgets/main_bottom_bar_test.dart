import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:s_map/commons/widgets/main_bottom_bar.dart';
import 'package:s_map/generated/codegen_loader.g.dart';

void main() {
  Widget buildTestApp() {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return Scaffold(
              body: navigationShell,
              bottomNavigationBar: AppMainBottomBar(navigationShell),
            );
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (_, __) => const Center(child: Text('Home Content')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/saved',
                  builder: (_, __) => const Center(child: Text('Saved Content')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/activity',
                  builder: (_, __) =>
                      const Center(child: Text('Activity Content')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/user',
                  builder: (_, __) => const Center(child: Text('User Content')),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    return EasyLocalization(
      supportedLocales: const [Locale('vi'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('vi'),
      startLocale: const Locale('vi'),
      assetLoader: const CodegenLoader(),
      child: Builder(
        builder: (context) {
          return MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
          );
        },
      ),
    );
  }

  group('AppMainBottomBar Integration Tests', () {
    testWidgets('renders all 4 tabs including "Hoạt động" with clock icon',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Trang chủ'), findsOneWidget);
      expect(find.text('Địa điểm'), findsOneWidget);
      expect(find.text('Hoạt động'), findsOneWidget);
      expect(find.text('Tài khoản'), findsOneWidget);

      final heroIcons = tester.widgetList<HeroIcon>(find.byType(HeroIcon));
      expect(
        heroIcons.any((icon) => icon.icon == HeroIcons.clock),
        isTrue,
        reason: 'Tab Hoạt động must use HeroIcons.clock',
      );
      expect(find.text('Home Content'), findsOneWidget);
    });

    testWidgets('tapping "Hoạt động" tab navigates to branch index 2',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Home Content'), findsOneWidget);
      expect(find.text('Activity Content'), findsNothing);

      // Tap on "Hoạt động" tab
      await tester.tap(find.text('Hoạt động'));
      await tester.pumpAndSettle();

      // Branch 2 is now active and displayed
      expect(find.text('Activity Content'), findsOneWidget);
    });
  });
}
