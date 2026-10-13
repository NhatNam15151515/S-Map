import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/widgets/app_button.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(child: child),
    ),
  );
}

void main() {
  group('AppButton Dumb Widget Tests', () {
    testWidgets('renders primary button text and responds to tap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        createTestApp(
          AppButton.primary(
            text: 'Đăng nhập',
            onPressed: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Đăng nhập'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);

      await tester.tap(find.byType(ElevatedButton));
      expect(tapped, isTrue);
    });

    testWidgets('displays loading spinner and disables click when isLoading is true', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        createTestApp(
          AppButton.primary(
            text: 'Đăng nhập',
            isLoading: true,
            onPressed: () => tapped = true,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Đăng nhập'), findsNothing);

      await tester.tap(find.byType(ElevatedButton));
      expect(tapped, isFalse);
    });

    testWidgets('renders outlined button with icon and text', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        createTestApp(
          AppButton.outlined(
            text: 'Tiếp tục với Google',
            icon: const Icon(Icons.g_mobiledata),
            onPressed: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Tiếp tục với Google'), findsOneWidget);
      expect(find.byIcon(Icons.g_mobiledata), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);

      await tester.tap(find.byType(OutlinedButton));
      expect(tapped, isTrue);
    });

    testWidgets('renders text button variant correctly', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        createTestApp(
          AppButton.text(
            text: 'Bỏ qua',
            onPressed: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Bỏ qua'), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);

      await tester.tap(find.byType(TextButton));
      expect(tapped, isTrue);
    });

    testWidgets('respects custom height, borderRadius and colors', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const AppButton(
            text: 'Bắt đầu',
            height: 70,
            borderRadius: 28,
            backgroundColor: Colors.white,
            textColor: Colors.blue,
            onPressed: null,
          ),
        ),
      );

      final sizeBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizeBox.height, 70);
      expect(find.text('Bắt đầu'), findsOneWidget);
    });
  });
}
