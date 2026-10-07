import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/widgets/app_setting_tile.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

void main() {
  group('AppSettingTile Reusable Dumb Widget Tests', () {
    testWidgets('renders title, subtitle, icon, chevron and handles onTap', (
      tester,
    ) async {
      bool tapped = false;

      await tester.pumpWidget(
        createTestApp(
          AppSettingTile(
            icon: Icons.language_rounded,
            title: 'Ngôn ngữ',
            subtitle: 'Tiếng Việt',
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ngôn ngữ'), findsOneWidget);
      expect(find.text('Tiếng Việt'), findsOneWidget);
      expect(find.byIcon(Icons.language_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      await tester.tap(find.byType(AppSettingTile));
      expect(tapped, isTrue);
    });

    testWidgets('renders custom trailing widget instead of chevron', (
      tester,
    ) async {
      bool switched = false;

      await tester.pumpWidget(
        createTestApp(
          AppSettingTile(
            icon: Icons.dark_mode_rounded,
            title: 'Chế độ tối',
            trailing: Switch(
              value: true,
              onChanged: (val) => switched = val,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Switch), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

      await tester.tap(find.byType(Switch));
      expect(switched, isFalse);
    });

    testWidgets('renders destructive styling correctly with error color', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          const AppSettingTile(
            icon: Icons.logout_rounded,
            title: 'Đăng xuất',
            isDestructive: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đăng xuất'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });

    testWidgets('renders AppSettingGroup, Divider, and SectionTitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          const Column(
            children: [
              AppSettingSectionTitle(title: 'CÀI ĐẶT CHUNG'),
              AppSettingGroup(
                children: [
                  AppSettingTile(
                    icon: Icons.map_rounded,
                    title: 'Loại bản đồ',
                  ),
                  AppSettingDivider(),
                  AppSettingTile(
                    icon: Icons.info_outline_rounded,
                    title: 'Thông tin',
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CÀI ĐẶT CHUNG'), findsOneWidget);
      expect(find.text('Loại bản đồ'), findsOneWidget);
      expect(find.text('Thông tin'), findsOneWidget);
      expect(find.byType(AppSettingDivider), findsOneWidget);
      expect(find.byType(AppSettingGroup), findsOneWidget);
    });
  });
}
