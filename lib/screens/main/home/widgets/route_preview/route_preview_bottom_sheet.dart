import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/screens/main/home/widgets/route_preview/route_preview_alt_route_selector.dart';
import 'package:s_map/screens/main/home/widgets/route_preview/route_preview_loading_card.dart';

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
    return BlocBuilder<RoutePreviewCubit, RoutePreviewState>(
      buildWhen: (previous, current) =>
          previous.status != current.status ||
          previous.currentRoute != current.currentRoute ||
          previous.selectedRouteIndex != current.selectedRouteIndex ||
          previous.profile != current.profile ||
          previous.originName != current.originName ||
          previous.destinationName != current.destinationName ||
          previous.alternativeRoutes != current.alternativeRoutes,
      builder: (context, state) {
        if (state.isLoading) {
          return RoutePreviewLoadingCard(onClose: onClose);
        }
        if (state.currentRoute == null) {
          return const SizedBox.shrink();
        }
        return _buildRouteInfoCard(context, state);
      },
    );
  }

  Widget _buildRouteInfoCard(BuildContext context, RoutePreviewState state) {
    final colorScheme = context.colorScheme;
    final themeColors = context.themeColors;
    final route = state.currentRoute!;
    final distanceStr = RouteFormatHelper.formatDistance(route.distance);
    final durationStr = RouteFormatHelper.formatDuration(route.time);
    final etaTimeStr = RouteFormatHelper.formatEtaClockTime(route.time);

    final vehicleIcon = _resolveVehicleIcon(state.profile);

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
          _buildInfoHeader(
            colorScheme,
            themeColors,
            vehicleIcon,
            durationStr,
            distanceStr,
            etaTimeStr,
            state,
          ),
          if (state.hasAlternativeRoutes) ...[
            const SizedBox(height: 12),
            RoutePreviewAltRouteSelector(
              alternativeRoutes: state.alternativeRoutes,
              selectedRouteIndex: state.selectedRouteIndex,
            ),
          ],
          const SizedBox(height: 16),
          _buildActionButtons(colorScheme),
        ],
      ),
    );
  }

  IconData _resolveVehicleIcon(String? profile) {
    if (profile == RoutingConstants.profileCar) {
      return Icons.directions_car_rounded;
    } else if (profile == RoutingConstants.profileFoot) {
      return Icons.directions_walk_rounded;
    }
    return Icons.two_wheeler_rounded;
  }

  Widget _buildInfoHeader(
    ColorScheme colorScheme,
    dynamic themeColors,
    IconData vehicleIcon,
    String durationStr,
    String distanceStr,
    String etaTimeStr,
    RoutePreviewState state,
  ) {
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
          child: Icon(vehicleIcon, color: colorScheme.primary, size: 24),
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

  Widget _buildActionButtons(ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          flex: 1,
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
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
            flex: 1,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
    );
  }
}
