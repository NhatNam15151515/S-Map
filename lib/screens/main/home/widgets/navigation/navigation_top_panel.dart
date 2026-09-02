import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/generated/locale_keys.g.dart';

/// Top HUD Banner hiển thị chỉ dẫn điều hướng Turn-by-Turn theo kiểu Google Maps:
/// - Icon rẽ lớn bên trái + khoảng cách
/// - "về hướng [Tên đường]" — tên đường cụ thể hoặc chỉ dẫn hành động
/// - Sub-panel: "Sau đó ➜ [hướng rẽ tiếp theo]"
class NavigationTopPanel extends StatelessWidget {
  final double? topPadding;

  const NavigationTopPanel({super.key, this.topPadding});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final themeColors = context.themeColors;

    return BlocBuilder<NavigationBloc, NavigationState>(
      buildWhen: (prev, curr) =>
          prev.currentInstruction != curr.currentInstruction ||
          prev.nextInstruction != curr.nextInstruction ||
          prev.distanceToNextInstruction != curr.distanceToNextInstruction ||
          prev.isPreAnnounced != curr.isPreAnnounced ||
          prev.isRerouting != curr.isRerouting ||
          prev.status != curr.status,
      builder: (context, state) {
        if (!state.isNavigating) {
          return const SizedBox.shrink();
        }

        final currentInstruction = state.currentInstruction;
        if (currentInstruction == null) {
          return const SizedBox.shrink();
        }

        final nextInstruction = state.nextInstruction;
        final icon = RouteFormatHelper.getInstructionIcon(
          currentInstruction.type,
        );
        final streetName = RouteFormatHelper.getInstructionTitle(currentInstruction);
        final distanceStr = RouteFormatHelper.formatDistance(
          state.distanceToNextInstruction,
        );

        // Xây dựng tiêu đề: "về hướng [Tên đường]"
        final toward = tr(LocaleKeys.routing_toward_direction);
        final hasStreetName = currentInstruction.streetName.isNotEmpty;

        return Positioned(
          top: (topPadding ?? MediaQuery.paddingOf(context).top) + 8,
          left: 12,
          right: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Reroute Status Indicator
              if (state.isRerouting)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tr(LocaleKeys.routing_rerouting),
                        style: colorScheme.onPrimary.textTheme.boldStyle.copyWith(
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

              // 2. Main Maneuver Banner — Kiểu Google Maps
              Container(
                decoration: BoxDecoration(
                  color: themeColors.statsSuccess,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Main instruction card
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Maneuver Icon — lớn, trắng
                          Icon(
                            icon,
                            color: themeColors.onStatsSuccess,
                            size: 44,
                          ),
                          const SizedBox(width: 14),

                          // Chỉ dẫn: "về hướng [Tên đường]" + khoảng cách
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Dòng 1: Khoảng cách tới ngã rẽ
                                Text(
                                  distanceStr,
                                  style: themeColors.onStatsSuccess.textTheme
                                      .boldStyle
                                      .copyWith(
                                    fontSize: 28,
                                    letterSpacing: -0.5,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                // Dòng 2: "về hướng [Tên đường]" hoặc chỉ dẫn hành động
                                Text(
                                  hasStreetName
                                      ? '$toward $streetName'
                                      : streetName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: themeColors.onStatsSuccess.textTheme
                                      .mediumStyle
                                      .copyWith(
                                    fontSize: 15,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 3. Next Turn Preview — "Sau đó ➜ [hướng rẽ tiếp theo]"
                    if (nextInstruction != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: themeColors.statsSuccess.withValues(alpha: 0.85),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(14),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              tr(LocaleKeys.routing_then_turn),
                              style: themeColors.onStatsSuccess.textTheme
                                  .regularStyle
                                  .copyWith(fontSize: 13),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              RouteFormatHelper.getInstructionIcon(
                                nextInstruction.type,
                              ),
                              color: themeColors.onStatsSuccess,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                RouteFormatHelper.getInstructionTitle(
                                  nextInstruction,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: themeColors.onStatsSuccess.textTheme
                                    .semiBoldStyle
                                    .copyWith(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
