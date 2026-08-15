import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/commons/widgets/widgets.dart';

class UserScreen extends StatefulWidget {
  static const String path = '/UserScreen';

  const UserScreen({super.key});

  @override
  _UserScreenState createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> with AppMixin, AuthMixin {
  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    super.dispose();
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
            // Profile header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const ProfileAvatar(size: 72, borderWidth: 2.5),
                  const SizedBox(height: 16),
                  Text(
                    "${currentProfile.username}",
                    style:
                        styles.blackTextColor.textTheme.subTitleStyle.copyWith(
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr(LocaleKeys.viewProfile),
                    style: AppColors.sMapTeal.textTheme.boldStyle.copyWith(
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Menu items
            _menuSection([
              _menuItem(
                  Icons.bookmark_rounded, tr(LocaleKeys.savedPlaces), () {}),
              _menuItem(
                  Icons.history_rounded, tr(LocaleKeys.activityHistory), () {}),
              _menuItem(
                  Icons.share_rounded, tr(LocaleKeys.shareLocation), () {}),
            ]),

            const SizedBox(height: 8),

            _menuSection([
              _menuItem(Icons.settings_rounded, tr(LocaleKeys.settings), () {}),
              _menuItem(Icons.help_outline_rounded,
                  tr(LocaleKeys.helpAndFeedback), () {}),
              _menuItem(
                  Icons.info_outline_rounded, tr(LocaleKeys.about), () {}),
            ]),

            const SizedBox(height: 8),

            _menuSection([
              _menuItem(Icons.logout_rounded, tr(LocaleKeys.logOut), () {
                authCubit.onLogout();
              }, isDestructive: true),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _menuSection(List<Widget> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: items,
      ),
    );
  }

  Widget _menuItem(IconData icon, String title, VoidCallback onTap,
      {bool isDestructive = false}) {
    final color =
        isDestructive ? AppColors.googleRed : AppColors.googleDarkText;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      (isDestructive ? AppColors.googleRed : AppColors.sMapTeal)
                          .withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    size: 20,
                    color: isDestructive
                        ? AppColors.googleRed
                        : AppColors.sMapTeal),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: color.textTheme.boldStyle.copyWith(fontSize: 15),
                ),
              ),
              if (!isDestructive)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.onSurfaceVariant,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
