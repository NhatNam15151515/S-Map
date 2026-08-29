import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/utils/utils.dart';

class AppMainBottomBar extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  const AppMainBottomBar(this.navigationShell, {super.key});

  @override
  State<AppMainBottomBar> createState() => _AppMainBottomBarState();
}

class _AppMainBottomBarState extends State<AppMainBottomBar> with AppMixin {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return Container(
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: bottomPadding + 8,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainer : AppColors.white,
        borderRadius: BorderRadius.circular(28),
        border: isDark
            ? Border.all(color: AppColors.darkOutline.withAlpha(60), width: 0.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 80 : 20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 50 : 8),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: _buildNavItem(HeroIcons.mapPin, false, isDark),
            activeIcon: _buildNavItem(HeroIcons.mapPin, true, isDark),
            label: tr(LocaleKeys.home),
          ),
          BottomNavigationBarItem(
            icon: _buildNavItem(HeroIcons.bookmark, false, isDark),
            activeIcon: _buildNavItem(HeroIcons.bookmark, true, isDark),
            label: tr(LocaleKeys.location),
          ),
          BottomNavigationBarItem(
            icon: _buildNavItem(HeroIcons.bell, false, isDark),
            activeIcon: _buildNavItem(HeroIcons.bell, true, isDark),
            label: tr(LocaleKeys.notification),
          ),
          BottomNavigationBarItem(
            icon: _buildNavItem(HeroIcons.userCircle, false, isDark),
            activeIcon: _buildNavItem(HeroIcons.userCircle, true, isDark),
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

  Widget _buildNavItem(HeroIcons icon, bool selected, bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: selected
            ? (isDark ? AppColors.sMapTeal.withAlpha(50) : AppColors.sMapLightTeal)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: HeroIcon(
        icon,
        size: 24,
        style: selected ? HeroIconStyle.solid : HeroIconStyle.outline,
        color: selected
            ? AppColors.sMapTeal
            : (isDark ? const Color(0xFF9AA0A6) : AppColors.onSurfaceVariant),
      ),
    );
  }

}
