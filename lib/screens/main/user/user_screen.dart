import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/routers/app_routes.dart';
import 'package:s_map/screens/main/user/widgets/widgets.dart';

class UserScreen extends StatelessWidget with AppMixin, AuthMixin {
  const UserScreen({super.key});

  void _shareLocation(BuildContext context) {
    final mapCubit = context.read<MapDisplayCubit>();
    final pos = mapCubit.state.currentPosition;
    final message = pos != null
        ? 'Vị trí hiện tại: https://maps.google.com/?q=${pos.latitude},${pos.longitude}'
        : 'Mở ứng dụng S-Map để khám phá và dẫn đường ngoại tuyến!';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

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
            // 1. Profile header card
            UserProfileCard(
              username: currentProfile.username,
              appName: appName,
              onViewProfile: () => UserProfileDetailDialog.show(context, currentProfile),
            ),

            // 2. Navigation menu items
            UserMenuCard(
              children: [
                UserMenuTile(
                  icon: Icons.bookmark_rounded,
                  title: tr(LocaleKeys.savedPlaces),
                  onTap: () => context.go(AppRoutes.saved),
                ),
                UserMenuTile(
                  icon: Icons.history_rounded,
                  title: tr(LocaleKeys.activityHistory),
                  onTap: () => context.push(AppRoutes.stats),
                ),
                UserMenuTile(
                  icon: Icons.share_rounded,
                  title: tr(LocaleKeys.shareLocation),
                  onTap: () => _shareLocation(context),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 3. Settings and About
            UserMenuCard(
              children: [
                UserMenuTile(
                  icon: Icons.settings_rounded,
                  title: tr(LocaleKeys.settings),
                  onTap: () => context.push(AppRoutes.settings),
                ),
                UserMenuTile(
                  icon: Icons.help_outline_rounded,
                  title: tr(LocaleKeys.helpAndFeedback),
                  onTap: () => HelpFeedbackDialog.show(context),
                ),
                UserMenuTile(
                  icon: Icons.info_outline_rounded,
                  title: tr(LocaleKeys.about),
                  onTap: () => context.push(AppRoutes.settings),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 4. Logout action
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
