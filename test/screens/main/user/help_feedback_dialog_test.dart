import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/generated/codegen_loader.g.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/screens/main/user/widgets/help_feedback_dialog.dart';

Widget createTestApp(Widget child) {
  return EasyLocalization(
    supportedLocales: const [Locale('vi')],
    path: 'assets/translations',
    fallbackLocale: const Locale('vi'),
    startLocale: const Locale('vi'),
    assetLoader: const CodegenLoader(),
    child: Builder(
      builder: (context) => MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        home: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HelpFeedbackDialog renders AppInfoDialog structure correctly', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => HelpFeedbackDialog.show(context),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(HelpFeedbackDialog), findsOneWidget);
    expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
    expect(find.text(tr(LocaleKeys.helpAndFeedback)), findsOneWidget);
    expect(find.text(tr(LocaleKeys.help_feedback_content)), findsOneWidget);
    expect(find.text(tr(LocaleKeys.close)), findsOneWidget);

    await tester.tap(find.text(tr(LocaleKeys.close)));
    await tester.pumpAndSettle();

    expect(find.byType(HelpFeedbackDialog), findsNothing);
  });
}
