import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class RoutePreviewBottomSheet extends StatelessWidget {
  final VoidCallback? onStartNavigation;
  final VoidCallback? onCustomRoute;
  final VoidCallback onClose;

  const RoutePreviewBottomSheet({
    super.key,
    this.onStartNavigation,
    this.onCustomRoute,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final themeColors = context.themeColors;

    return BlocBuilder<RoutePreviewCubit, RoutePreviewState>(
      builder: (context, state) {
        if (state.isLoading) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    tr(LocaleKeys.routing_calculating_moped_route),
                    style: colorScheme.onSurface.textTheme.mediumStyle.copyWith(
                      fontSize: 14,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  onPressed: onClose,
                  tooltip: tr(LocaleKeys.cancel),
                ),
              ],
            ),
          );
        }

        if (state.currentRoute == null) {
          return const SizedBox.shrink();
        }

        final route = state.currentRoute!;
        final distanceStr = RouteFormatHelper.formatDistance(route.distance);
        final durationStr = RouteFormatHelper.formatDuration(route.time);
        final etaTimeStr = RouteFormatHelper.formatEtaClockTime(route.time);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outline.withAlpha(50),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Info Header Row (Motorcycle Icon + Duration/Distance + Close Button)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Phương tiện di chuyển Icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.two_wheeler_rounded,
                      color: colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Thời gian & Khoảng cách & Tên điểm đến
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              durationStr,
                              style: colorScheme.onSurface.textTheme.boldStyle.copyWith(
                                fontSize: 18,
                                color: themeColors.statsSuccess,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '($distanceStr)',
                              style: colorScheme.onSurfaceVariant.textTheme.textStyle.copyWith(
                                fontSize: 14,
                                fontWeight: AppFontWeight.regular.weight,
                              ),
                            ),
                          ],
                        ),
                        if (state.destinationName != null &&
                            state.destinationName!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            state.destinationName!,
                            style: colorScheme.onSurface.textTheme.semiBoldStyle.copyWith(
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          '${tr(LocaleKeys.routing_remaining)}: $etaTimeStr',
                          style: colorScheme.onSurfaceVariant.textTheme.textStyle.copyWith(
                            fontSize: 12,
                            fontWeight: AppFontWeight.regular.weight,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Nút Đóng preview
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    onPressed: onClose,
                    tooltip: tr(LocaleKeys.cancel),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Action: Start Navigation & Custom Route Buttons
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: ElevatedButton.icon(
                      onPressed: onStartNavigation,
                      icon: Icon(
                        Icons.navigation_rounded,
                        size: 20,
                        color: colorScheme.onPrimary,
                      ),
                      label: Text(
                        tr(LocaleKeys.routing_start_navigation),
                        style: colorScheme.onPrimary.textTheme.boldStyle.copyWith(
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  if (onCustomRoute != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: OutlinedButton.icon(
                        onPressed: onCustomRoute,
                        icon: Icon(
                          Icons.gesture_rounded,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        label: Text(
                          tr(LocaleKeys.route_drawing_ui_custom_route_drawing),
                          style: colorScheme.primary.textTheme.semiBoldStyle.copyWith(
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.primary,
                          side: BorderSide(
                            color: colorScheme.primary.withAlpha(120),
                            width: 1.2,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
