import 'package:s_map/commons/mixin/app_mixin.dart';
import 'package:s_map/commons/mixin/auth_mixin.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/commons/widgets/app_bar.dart';
import 'package:s_map/commons/widgets/user_avatar.dart';
import 'package:flutter/material.dart';

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
        title: locale.profile,
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
                    style: styles.blackTextColor.textTheme.subTitleStyle.copyWith(
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Xem hồ sơ",
                    style: AppColors.sMapTeal.textTheme.boldStyle.copyWith(
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Menu items
            _menuSection([
              _menuItem(Icons.bookmark_rounded, "Địa điểm đã lưu", () {}),
              _menuItem(Icons.history_rounded, "Lịch sử hoạt động", () {}),
              _menuItem(Icons.share_rounded, "Chia sẻ vị trí", () {}),
            ]),

            const SizedBox(height: 8),

            _menuSection([
              _menuItem(Icons.settings_rounded, "Cài đặt", () {}),
              _menuItem(Icons.help_outline_rounded, "Trợ giúp & phản hồi", () {}),
              _menuItem(Icons.info_outline_rounded, "Giới thiệu", () {}),
            ]),

            const SizedBox(height: 8),

            _menuSection([
              _menuItem(Icons.logout_rounded, "Đăng xuất", () {
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

  Widget _menuItem(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    final color = isDestructive ? AppColors.googleRed : AppColors.googleDarkText;
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
                  color: (isDestructive ? AppColors.googleRed : AppColors.sMapTeal).withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: isDestructive ? AppColors.googleRed : AppColors.sMapTeal),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: color.textTheme.boldStyle.copyWith(fontSize: 15),
                ),
              ),
              if (!isDestructive) const Icon(
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
