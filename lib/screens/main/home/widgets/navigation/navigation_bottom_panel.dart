import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/generated/locale_keys.g.dart';

/// Bottom Navigation Bar hiển thị Speedometer thời gian thực, khoảng cách còn lại, ETA và nút Kết thúc
class NavigationBottomPanel extends StatelessWidget {
  final VoidCallback onStopNavigation;

  const NavigationBottomPanel({
    super.key,
    required this.onStopNavigation,
  });

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);

    return BlocBuilder<NavigationBloc, NavigationState>(
      buildWhen: (prev, curr) =>
          prev.currentSpeedKmh != curr.currentSpeedKmh ||
          prev.remainingDistance != curr.remainingDistance ||
          prev.remainingDurationMs != curr.remainingDurationMs ||
          prev.status != curr.status,
      builder: (context, state) {
        if (!state.isNavigating) {
          return const SizedBox.shrink();
        }

        final speedStr = RouteFormatHelper.formatSpeed(state.currentSpeedKmh);
        final remainingDistStr = RouteFormatHelper.formatDistance(
          state.remainingDistance,
        );
        final remainingDurationStr = RouteFormatHelper.formatDuration(
          state.remainingDurationMs,
        );
        final etaTimeStr = RouteFormatHelper.formatEtaClockTime(
          state.remainingDurationMs,
        );

        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.outlineVariant.withAlpha(120),
                  width: 0.8,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.12),
                    blurRadius: 20,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // 1. Speedometer Card
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          speedStr,
                          style:
                              style.blackTextColor.textTheme.boldStyle.copyWith(
                            fontSize: 20,
                            letterSpacing: -0.5,
                            color: AppColors.googleDarkText,
                          ),
                        ),
                        Text(
                          tr(LocaleKeys.routing_speed_kmh),
                          style: style.blackTextColor.textTheme.mediumStyle
                              .copyWith(
                            fontSize: 10,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),

                  // 2. Remaining Distance & ETA Clock Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text.rich(
                          TextSpan(
                            text: remainingDurationStr,
                            style: style.blackTextColor.textTheme.boldStyle
                                .copyWith(
                              fontSize: 17,
                              color: AppColors.navAccentGreen,
                            ),
                            children: [
                              TextSpan(
                                text: ' • $etaTimeStr',
                                style: style
                                    .blackTextColor.textTheme.mediumStyle
                                    .copyWith(
                                  fontSize: 13,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$remainingDistStr ${tr(LocaleKeys.routing_remaining)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: style.blackTextColor.textTheme.regularStyle
                              .copyWith(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3. Nút "Kết thúc" (Stop Navigation Button)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onStopNavigation,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.navAlertRed.withAlpha(25),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.navAlertRed.withAlpha(80),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.close_rounded,
                              color: AppColors.navAlertRed,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              tr(LocaleKeys.routing_end_navigation),
                              style: style.blackTextColor.textTheme.boldStyle
                                  .copyWith(
                                fontSize: 13,
                                color: AppColors.navAlertRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
