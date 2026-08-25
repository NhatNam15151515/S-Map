import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/codegen_loader.g.dart';

Widget createTestableWidget(Widget child) {
  return EasyLocalization(
    supportedLocales: const [Locale('vi'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('vi'),
    startLocale: const Locale('vi'),
    assetLoader: const CodegenLoader(),
    child: BlocProvider(
      create: (_) => AppCubit(),
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

  group('SearchThisAreaButton Widget Tests', () {
    testWidgets('renders correctly when visible and triggers onPressed', (tester) async {
      bool pressed = false;

      await tester.pumpWidget(createTestableWidget(
        SearchThisAreaButton(
          isVisible: true,
          isLoading: false,
          onPressed: () => pressed = true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(SearchThisAreaButton), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

      await tester.tap(find.byType(SearchThisAreaButton));
      await tester.pump();

      expect(pressed, isTrue);
    });

    testWidgets('renders loading indicator when isLoading is true and ignores taps', (tester) async {
      bool pressed = false;

      await tester.pumpWidget(createTestableWidget(
        SearchThisAreaButton(
          isVisible: true,
          isLoading: true,
          onPressed: () => pressed = true,
        ),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byType(SearchThisAreaButton));
      await tester.pump();

      expect(pressed, isFalse);
    });
  });
}
