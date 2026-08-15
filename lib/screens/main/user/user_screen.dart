import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/screens/main/user/widgets/widgets.dart';

class UserScreen extends StatefulWidget {
  static const String path = '/UserScreen';

  const UserScreen({super.key});

  @override
  _UserScreenState createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> with AppMixin, AuthMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleAppBar(
        title: tr(LocaleKeys.profile),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: marginBottomDefault),
        child: Column(
          children: [
            // Profile header card
            UserProfileCard(
              username: currentProfile.username,
              appName: appName,
              onViewProfile: () {},
            ),

            // Navigation menu items
            UserMenuCard(
              children: [
                UserMenuTile(
                  icon: Icons.bookmark_rounded,
                  title: tr(LocaleKeys.savedPlaces),
                  onTap: () {},
                ),
                UserMenuTile(
                  icon: Icons.history_rounded,
                  title: tr(LocaleKeys.activityHistory),
                  onTap: () {},
                ),
                UserMenuTile(
                  icon: Icons.share_rounded,
                  title: tr(LocaleKeys.shareLocation),
                  onTap: () {},
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Settings and About
            UserMenuCard(
              children: [
                UserMenuTile(
                  icon: Icons.settings_rounded,
                  title: tr(LocaleKeys.settings),
                  onTap: () {},
                ),
                UserMenuTile(
                  icon: Icons.help_outline_rounded,
                  title: tr(LocaleKeys.helpAndFeedback),
                  onTap: () {},
                ),
                UserMenuTile(
                  icon: Icons.info_outline_rounded,
                  title: tr(LocaleKeys.about),
                  onTap: () {},
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Logout action
            UserMenuCard(
              children: [
                UserMenuTile(
                  icon: Icons.logout_rounded,
                  title: tr(LocaleKeys.logOut),
                  onTap: () => authCubit.onLogout(),
                  isDestructive: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
