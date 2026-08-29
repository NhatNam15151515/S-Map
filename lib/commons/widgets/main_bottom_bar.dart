import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:s_map/commons/mixin/mixin.dart';

class AppMainBottomBar extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  const AppMainBottomBar(this.navigationShell, {super.key});

  @override
  State<AppMainBottomBar> createState() => _AppMainBottomBarState();
}

class _AppMainBottomBarState extends State<AppMainBottomBar> with AppMixin {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: bottomPadding + 8,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colorScheme.outline.withAlpha(50),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: _buildNavItem(HeroIcons.mapPin, false, colorScheme),
            activeIcon: _buildNavItem(HeroIcons.mapPin, true, colorScheme),
            label: tr(LocaleKeys.home),
          ),
          BottomNavigationBarItem(
            icon: _buildNavItem(HeroIcons.bookmark, false, colorScheme),
            activeIcon: _buildNavItem(HeroIcons.bookmark, true, colorScheme),
            label: tr(LocaleKeys.location),
          ),
          BottomNavigationBarItem(
            icon: _buildNavItem(HeroIcons.bell, false, colorScheme),
            activeIcon: _buildNavItem(HeroIcons.bell, true, colorScheme),
            label: tr(LocaleKeys.notification),
          ),
          BottomNavigationBarItem(
            icon: _buildNavItem(HeroIcons.userCircle, false, colorScheme),
            activeIcon: _buildNavItem(HeroIcons.userCircle, true, colorScheme),
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

  Widget _buildNavItem(HeroIcons icon, bool selected, ColorScheme colorScheme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color:
            selected ? colorScheme.primary.withAlpha(35) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: HeroIcon(
        icon,
        size: 24,
        style: selected ? HeroIconStyle.solid : HeroIconStyle.outline,
        color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
      ),
    );
  }
}
