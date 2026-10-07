import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/screens/main/user/widgets/user_menu_card.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

void main() {
  group('UserMenuCard & UserMenuTile Adapter Tests', () {
    testWidgets('renders menu items and triggers onTap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        createTestApp(
          UserMenuCard(
            children: [
              UserMenuTile(
                icon: Icons.bookmark_rounded,
                title: 'Địa điểm đã lưu',
                onTap: () => tapped = true,
              ),
              UserMenuTile(
                icon: Icons.logout_rounded,
                title: 'Đăng xuất',
                isDestructive: true,
                onTap: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Địa điểm đã lưu'), findsOneWidget);
      expect(find.text('Đăng xuất'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);

      await tester.tap(find.text('Địa điểm đã lưu'));
      expect(tapped, isTrue);
    });
  });
}
