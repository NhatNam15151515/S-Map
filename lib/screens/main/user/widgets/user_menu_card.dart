import 'package:flutter/material.dart';
import 'package:s_map/commons/widgets/app_setting_tile.dart';

class UserMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const UserMenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppSettingTile(
      icon: icon,
      title: title,
      onTap: onTap,
      isDestructive: isDestructive,
    );
  }
}

class UserMenuCard extends StatelessWidget {
  final List<Widget> children;

  const UserMenuCard({
    super.key,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return AppSettingGroup(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      hasBorder: true,
      children: children,
    );
  }
}
