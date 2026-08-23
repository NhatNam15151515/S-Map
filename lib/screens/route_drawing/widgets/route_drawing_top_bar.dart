import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class RouteDrawingTopBar extends StatelessWidget {
  final double topPadding;
  final VoidCallback onSavedRoutesPressed;

  const RouteDrawingTopBar({
    super.key,
    required this.topPadding,
    required this.onSavedRoutesPressed,
  });

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);

    return Positioned(
      top: topPadding + 10,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withAlpha(15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              key: const Key('route_drawing_back_button'),
              icon: const HeroIcon(
                HeroIcons.chevronLeft,
                size: 24,
                color: AppColors.black,
              ),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                }
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr(LocaleKeys.route_drawing_ui_title),
                    style: style.blackTextColor.textTheme.boldStyle.copyWith(
                      fontSize: 16,
                      color: AppColors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.sMapLightTeal,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.two_wheeler_rounded,
                              size: 12,
                              color: AppColors.sMapDarkTeal,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              tr(LocaleKeys.route_drawing_ui_profile_moped),
                              style: style.blackTextColor.textTheme.semiBoldStyle.copyWith(
                                fontSize: 10,
                                color: AppColors.sMapDarkTeal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              key: const Key('route_drawing_saved_routes_button'),
              icon: const HeroIcon(
                HeroIcons.bookmark,
                size: 22,
                color: AppColors.sMapTeal,
              ),
              tooltip: tr(LocaleKeys.route_drawing_ui_saved_routes_title),
              onPressed: onSavedRoutesPressed,
            ),
          ],
        ),
      ),
    );
  }
}
