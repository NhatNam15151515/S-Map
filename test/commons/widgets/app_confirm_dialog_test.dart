import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/widgets/app_confirm_dialog.dart';
import 'package:s_map/generated/codegen_loader.g.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget createTestApp(Widget child) {
  return EasyLocalization(
    supportedLocales: const [Locale('vi'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('vi'),
    startLocale: const Locale('vi'),
    assetLoader: const CodegenLoader(),
    child: Builder(
      builder: (context) => MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        home: Scaffold(
          body: Center(child: child),
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

  group('AppConfirmDialog Tests', () {
    testWidgets('renders without throwing ParentData exception and taps cancel', (tester) async {
      bool? result;
      bool onCancelCalled = false;

      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await AppConfirmDialog.show(
                    context,
                    title: 'Xác nhận thoát',
                    message: 'Bạn có muốn hủy vẽ lộ trình?',
                    confirmKey: const Key('route_drawing_exit_confirm_button'),
                    cancelKey: const Key('route_drawing_exit_cancel_button'),
                    onCancel: () => onCancelCalled = true,
                  );
                },
                child: const Text('Show Dialog'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(AppConfirmDialog), findsOneWidget);
      expect(find.byKey(const Key('route_drawing_exit_cancel_button')), findsOneWidget);
      expect(find.byKey(const Key('route_drawing_exit_confirm_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('route_drawing_exit_cancel_button')));
      await tester.pumpAndSettle();

      expect(find.byType(AppConfirmDialog), findsNothing);
      expect(result, isFalse);
      expect(onCancelCalled, isTrue);
    });

    testWidgets('taps confirm returns true and calls onConfirm', (tester) async {
      bool? result;
      bool onConfirmCalled = false;

      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await AppConfirmDialog.show(
                    context,
                    title: 'Xóa mục này?',
                    message: 'Thao tác không thể hoàn tác.',
                    isDestructive: true,
                    confirmKey: const Key('confirm_btn'),
                    cancelKey: const Key('cancel_btn'),
                    onConfirm: () => onConfirmCalled = true,
                  );
                },
                child: const Text('Show Dialog'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm_btn')));
      await tester.pumpAndSettle();

      expect(find.byType(AppConfirmDialog), findsNothing);
      expect(result, isTrue);
      expect(onConfirmCalled, isTrue);
    });
  });
}
