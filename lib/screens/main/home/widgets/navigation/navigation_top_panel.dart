import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/generated/locale_keys.g.dart';

/// Top HUD Banner hiển thị chỉ dẫn điều hướng Turn-by-Turn (Khoảng cách, Icon rẽ, Tên đường, Preview bước tiếp theo)
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
        final title = RouteFormatHelper.getInstructionTitle(currentInstruction);
        final distanceStr = RouteFormatHelper.formatDistance(
          state.distanceToNextInstruction,
        );

        return Positioned(
          top: (topPadding ?? MediaQuery.paddingOf(context).top) + 8,
          left: 12,
          right: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Reroute Status Indicator (nếu đang tính lại đường)
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

              // 2. Main Maneuver Banner
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: state.isPreAnnounced
                        ? themeColors.statsSuccess
                        : colorScheme.outline.withAlpha(60),
                    width: state.isPreAnnounced ? 1.8 : 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Main Step Card
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Maneuver Icon Container
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withAlpha(25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              icon,
                              color: colorScheme.primary,
                              size: 36,
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Distance & Instruction Street Name
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      distanceStr,
                                      style: colorScheme.onSurface.textTheme
                                          .boldStyle
                                          .copyWith(
                                        fontSize: 22,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    if (state.isPreAnnounced) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: themeColors.statsSuccess
                                              .withAlpha(200),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          tr(LocaleKeys.routing_prepare_turn),
                                          style: themeColors.onStatsSuccess.textTheme
                                              .semiBoldStyle
                                              .copyWith(fontSize: 10),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: colorScheme.onSurfaceVariant.textTheme
                                      .mediumStyle
                                      .copyWith(
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 3. Next Turn Preview (nếu có chặng rẽ tiếp theo)
                    if (nextInstruction != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(15),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${tr(LocaleKeys.routing_then_turn)}: ',
                              style: colorScheme.onSurfaceVariant.textTheme.regularStyle
                                  .copyWith(
                                fontSize: 12,
                              ),
                            ),
                            Icon(
                              RouteFormatHelper.getInstructionIcon(
                                nextInstruction.type,
                              ),
                              color: colorScheme.onSurfaceVariant,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                RouteFormatHelper.getInstructionTitle(
                                  nextInstruction,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: colorScheme.onSurface.textTheme
                                    .semiBoldStyle
                                    .copyWith(
                                  fontSize: 12,
                                ),
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
