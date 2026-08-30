import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:s_map/commons/styles/styles.dart';
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
    final colorScheme = Theme.of(context).colorScheme;

    return Positioned(
      top: topPadding + 10,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outline.withAlpha(50),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              key: const Key('route_drawing_back_button'),
              icon: HeroIcon(
                HeroIcons.chevronLeft,
                size: 24,
                color: colorScheme.onSurface,
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
                    style: colorScheme.onSurface.textTheme.boldStyle.copyWith(
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.two_wheeler_rounded,
                              size: 12,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              tr(LocaleKeys.route_drawing_ui_profile_moped),
                              style: colorScheme.primary.textTheme.semiBoldStyle
                                  .copyWith(
                                fontSize: 10,
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
              icon: HeroIcon(
                HeroIcons.bookmark,
                size: 22,
                color: colorScheme.primary,
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
