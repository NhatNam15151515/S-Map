import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/generated/locale_keys.g.dart';

/// Floating Top Banner hiển thị chỉ dẫn hướng rẽ, khoảng cách đến ngã rẽ và tên đường
class NavigationTopPanel extends StatelessWidget {
  final double topPadding;

  const NavigationTopPanel({
    super.key,
    required this.topPadding,
  });

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);

    return BlocBuilder<NavigationBloc, NavigationState>(
      buildWhen: (prev, curr) =>
          prev.distanceToNextInstruction != curr.distanceToNextInstruction ||
          prev.currentInstruction != curr.currentInstruction ||
          prev.nextInstruction != curr.nextInstruction ||
          prev.isPreAnnounced != curr.isPreAnnounced ||
          prev.isRerouting != curr.isRerouting ||
          prev.status != curr.status,
      builder: (context, state) {
        if (!state.isNavigating) {
          return const SizedBox.shrink();
        }

        final instruction = state.currentInstruction;
        final icon = RouteFormatHelper.getInstructionIcon(state.instructionType);
        final distanceStr = RouteFormatHelper.formatDistance(
          state.distanceToNextInstruction,
        );
        final title = RouteFormatHelper.getInstructionTitle(instruction);
        final nextInstruction = state.nextInstruction;

        return Positioned(
          top: topPadding + 8,
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
                    color: AppColors.bleuDeFrance,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.2),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tr(LocaleKeys.routing_rerouting),
                        style:
                            style.whiteTextColor.textTheme.boldStyle.copyWith(
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

              // 2. Main Maneuver Banner
              Container(
                decoration: BoxDecoration(
                  color: AppColors.navDarkSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: state.isPreAnnounced
                        ? AppColors.navAccentGreen
                        : AppColors.navCardBorder,
                    width: state.isPreAnnounced ? 1.8 : 0.8,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.28),
                      blurRadius: 16,
                      offset: Offset(0, 6),
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
                              color: AppColors.navManeuverBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              icon,
                              color: Colors.white,
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
                                      style: style.whiteTextColor.textTheme
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
                                          color: AppColors.navAccentGreen
                                              .withAlpha(200),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          tr(LocaleKeys.routing_prepare_turn),
                                          style: style.whiteTextColor.textTheme
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
                                  style: style.whiteTextColor.textTheme
                                      .mediumStyle
                                      .copyWith(
                                    fontSize: 15,
                                    color: Colors.white.withAlpha(230),
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
                          color: Colors.black.withAlpha(80),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(15),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${tr(LocaleKeys.routing_then_turn)}: ',
                              style: style.whiteTextColor.textTheme.regularStyle
                                  .copyWith(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                            Icon(
                              RouteFormatHelper.getInstructionIcon(
                                nextInstruction.type,
                              ),
                              color: Colors.white70,
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
                                style: style.whiteTextColor.textTheme
                                    .semiBoldStyle
                                    .copyWith(
                                  fontSize: 12,
                                  color: Colors.white,
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
