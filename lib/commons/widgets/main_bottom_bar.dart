import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:s_map/commons/mixin/app_mixin.dart';
import 'package:s_map/commons/utils/app_colors.dart';

class AppMainBottomBar extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  const AppMainBottomBar(this.navigationShell, {super.key});

  @override
  State<AppMainBottomBar> createState() => _AppMainBottomBarState();
}

class _AppMainBottomBarState extends State<AppMainBottomBar> with AppMixin {
  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return Container(
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: bottomPadding + 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: _buildNavItem(HeroIcons.mapPin, false),
            activeIcon: _buildNavItem(HeroIcons.mapPin, true),
            label: tr(LocaleKeys.home),
          ),
          BottomNavigationBarItem(
            icon: _buildNavItem(HeroIcons.bookmark, false),
            activeIcon: _buildNavItem(HeroIcons.bookmark, true),
            label: tr(LocaleKeys.location),
          ),
          BottomNavigationBarItem(
            icon: _buildNavItem(HeroIcons.bell, false),
            activeIcon: _buildNavItem(HeroIcons.bell, true),
            label: tr(LocaleKeys.notification),
          ),
          BottomNavigationBarItem(
            icon: _buildNavItem(HeroIcons.userCircle, false),
            activeIcon: _buildNavItem(HeroIcons.userCircle, true),
            label: tr(LocaleKeys.account),
          ),
        ],
        currentIndex: widget.navigationShell.currentIndex,
        onTap: (index) {
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          );
        },
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
    );
  }

  Widget _buildNavItem(HeroIcons icon, bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: selected ? AppColors.sMapLightTeal : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: HeroIcon(
        icon,
        size: 24,
        style: selected ? HeroIconStyle.solid : HeroIconStyle.outline,
        color: selected ? AppColors.sMapTeal : AppColors.onSurfaceVariant,
      ),
    );
  }
}
