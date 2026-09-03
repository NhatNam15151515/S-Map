import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/generated/locale_keys.g.dart';

/// Header chỉ đường chuẩn Google Maps với 2 ô chọn điểm xuất phát / điểm đến và nút hoán đổi chiều
class RouteDirectionHeader extends StatelessWidget {
  final double topPadding;
  final VoidCallback onSelectOrigin;
  final VoidCallback onSelectDestination;
  final VoidCallback onClose;

  const RouteDirectionHeader({
    super.key,
    required this.topPadding,
    required this.onSelectOrigin,
    required this.onSelectDestination,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return BlocBuilder<RoutePreviewCubit, RoutePreviewState>(
      builder: (context, state) {
        final originName =
            state.originName ?? tr(LocaleKeys.routing_my_location);
        final destinationName =
            state.destinationName ?? tr(LocaleKeys.routing_destination_fallback);
        final currentProfile = state.profile;

        return Positioned(
          top: topPadding + 8,
          left: 16,
          right: 16,
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.15),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // Back button
                    IconButton(
                      key: const Key('route_direction_back_btn'),
                      icon: const Icon(Icons.arrow_back_rounded, size: 22),
                      onPressed: onClose,
                      tooltip: tr(LocaleKeys.common_cancel),
                    ),

                    // Two input fields (Origin & Destination)
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. Origin Input Field
                          _buildEndpointBox(
                            context: context,
                            icon: Icons.my_location_rounded,
                            iconColor: Colors.blueAccent,
                            label: originName,
                            isDefaultLocation: state.isOriginCurrentLocation,
                            onTap: onSelectOrigin,
                          ),
                          const SizedBox(height: 6),
                          // 2. Destination Input Field
                          _buildEndpointBox(
                            context: context,
                            icon: Icons.location_on_rounded,
                            iconColor: Colors.redAccent,
                            label: destinationName,
                            isDefaultLocation: false,
                            onTap: onSelectDestination,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Swap Button (Đổi chỗ A <-> B)
                    IconButton(
                      key: const Key('route_direction_swap_btn'),
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.swap_vert_rounded,
                          size: 22,
                          color: colorScheme.primary,
                        ),
                      ),
                      tooltip: tr(LocaleKeys.routing_reroute_success),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        context.read<RoutePreviewCubit>().swapEndpoints();
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 8),

                // Vehicle Profile Selector (Xe máy, Ô tô, Đi bộ)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildProfileChip(
                      context: context,
                      profileKey: RoutingConstants.profileMopedVn,
                      icon: Icons.two_wheeler_rounded,
                      label: tr(LocaleKeys.route_drawing_ui_profile_moped),
                      isSelected: currentProfile ==
                              RoutingConstants.profileMopedVn ||
                          currentProfile == RoutingConstants.profileBike,
                    ),
                    _buildProfileChip(
                      context: context,
                      profileKey: RoutingConstants.profileCar,
                      icon: Icons.directions_car_rounded,
                      label: tr(LocaleKeys.route_drawing_ui_profile_car),
                      isSelected:
                          currentProfile == RoutingConstants.profileCar,
                    ),
                    _buildProfileChip(
                      context: context,
                      profileKey: RoutingConstants.profileFoot,
                      icon: Icons.directions_walk_rounded,
                      label: tr(LocaleKeys.route_drawing_ui_profile_foot),
                      isSelected:
                          currentProfile == RoutingConstants.profileFoot,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEndpointBox({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String label,
    required bool isDefaultLocation,
    required VoidCallback onTap,
  }) {
    final colorScheme = context.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.1),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: colorScheme.onSurface.textTheme.mediumStyle.copyWith(
                  fontSize: 13.5,
                  fontWeight: isDefaultLocation ? FontWeight.w500 : FontWeight.w600,
                  color: isDefaultLocation
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.search_rounded,
              size: 16,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileChip({
    required BuildContext context,
    required String profileKey,
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    final colorScheme = context.colorScheme;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        context.read<RoutePreviewCubit>().changeProfile(profileKey);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.15),
            width: isSelected ? 1.4 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
