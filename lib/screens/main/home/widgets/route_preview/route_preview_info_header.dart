import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/generated/locale_keys.g.dart';

/// Header hiển thị thông tin thời gian, khoảng cách, icon xe máy và nút đóng
class RoutePreviewInfoHeader extends StatelessWidget {
  final String durationStr;
  final String distanceStr;
  final String etaTimeStr;
  final RoutePreviewState state;
  final VoidCallback onClose;

  const RoutePreviewInfoHeader({
    super.key,
    required this.durationStr,
    required this.distanceStr,
    required this.etaTimeStr,
    required this.state,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final themeColors = context.themeColors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
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
              if (state.originName != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${state.originName} → ${state.destinationName ?? tr(LocaleKeys.routing_destination_fallback)}',
                  style: colorScheme.onSurface.textTheme.semiBoldStyle.copyWith(
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ] else if (state.destinationName != null &&
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
    );
  }
}
