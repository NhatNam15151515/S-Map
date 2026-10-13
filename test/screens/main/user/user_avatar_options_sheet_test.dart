import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/codegen_loader.g.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/screens/main/user/widgets/user_avatar_options_sheet.dart';

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

  group('UserAvatarOptionsSheet Dumb Widget Tests', () {
    testWidgets('renders all options using AppSettingGroup and triggers callbacks', (tester) async {
      bool viewedAvatar = false;
      bool tookPhoto = false;
      bool pickedGallery = false;
      bool deletedAvatar = false;

      await tester.pumpWidget(
        createTestApp(
          UserAvatarOptionsSheet(
            hasAvatar: true,
            onViewAvatar: () => viewedAvatar = true,
            onTakePhoto: () => tookPhoto = true,
            onPickGallery: () => pickedGallery = true,
            onDeleteAvatar: () => deletedAvatar = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppSettingGroup), findsOneWidget);
      expect(find.text(tr(LocaleKeys.user_avatar_title)), findsOneWidget);
      expect(find.byKey(const Key('avatar_option_view')), findsOneWidget);
      expect(find.byKey(const Key('avatar_option_camera')), findsOneWidget);
      expect(find.byKey(const Key('avatar_option_gallery')), findsOneWidget);
      expect(find.byKey(const Key('avatar_option_delete')), findsOneWidget);

      await tester.tap(find.byKey(const Key('avatar_option_view')));
      expect(viewedAvatar, isTrue);

      await tester.tap(find.byKey(const Key('avatar_option_camera')));
      expect(tookPhoto, isTrue);

      await tester.tap(find.byKey(const Key('avatar_option_gallery')));
      expect(pickedGallery, isTrue);

      await tester.tap(find.byKey(const Key('avatar_option_delete')));
      expect(deletedAvatar, isTrue);
    });

    testWidgets('hides view and delete options when hasAvatar is false', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          UserAvatarOptionsSheet(
            hasAvatar: false,
            onTakePhoto: () {},
            onPickGallery: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('avatar_option_view')), findsNothing);
      expect(find.byKey(const Key('avatar_option_delete')), findsNothing);
      expect(find.byKey(const Key('avatar_option_camera')), findsOneWidget);
      expect(find.byKey(const Key('avatar_option_gallery')), findsOneWidget);
    });
  });
}
