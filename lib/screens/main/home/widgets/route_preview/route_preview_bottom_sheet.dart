import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class RoutePreviewBottomSheet extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback? onStartNavigation;

  const RoutePreviewBottomSheet({
    super.key,
    required this.onClose,
    this.onStartNavigation,
  });

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);

    return BlocBuilder<RoutePreviewCubit, RoutePreviewState>(
      builder: (context, state) {
        if (state.isLoading) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.12),
                  blurRadius: 16,
                  offset: Offset(0, 6),
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
                    style: style.blackTextColor.textTheme.boldStyle.copyWith(
                      fontSize: 14,
                      color: AppColors.googleDarkText,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppColors.onSurfaceVariant,
                  ),
                  onPressed: onClose,
                  tooltip: tr(LocaleKeys.cancel),
                ),
              ],
            ),
          );
        }

        if (!state.isSuccess || state.routeResult == null) {
          return const SizedBox.shrink();
        }

        final route = state.routeResult!;
        final distanceStr = RouteFormatHelper.formatDistance(route.distance);
        final durationStr = RouteFormatHelper.formatDuration(route.time);
        final destinationName = state.destinationName?.isNotEmpty == true
            ? state.destinationName!
            : tr(LocaleKeys.routing_destination_fallback);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.outlineVariant.withAlpha(100),
              width: 0.8,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.12),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header: Xe máy icon + Duration + Distance + Close button
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.sMapTeal.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      RouteFormatHelper.motorcycleIcon,
                      color: AppColors.sMapTeal,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              durationStr,
                              style: style.blackTextColor.textTheme.boldStyle.copyWith(
                                fontSize: 18,
                                color: AppColors.googleGreen,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '($distanceStr)',
                              style: AppColors.onSurfaceVariant.textTheme.textStyle.copyWith(
                                fontSize: 14,
                                fontWeight: AppFontWeight.regular.weight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          destinationName,
                          style: AppColors.onSurfaceVariant.textTheme.textStyle.copyWith(
                            fontSize: 13,
                            color: AppColors.googleDarkText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.onSurfaceVariant,
                    ),
                    onPressed: onClose,
                    tooltip: tr(LocaleKeys.cancel),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 2. Action: Start Navigation Button
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onStartNavigation,
                      icon: const Icon(
                        Icons.navigation_rounded,
                        size: 20,
                        color: AppColors.white,
                      ),
                      label: Text(
                        tr(LocaleKeys.routing_start_navigation),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sMapTeal,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
