import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/screens/main/home/widgets/route_preview/route_endpoint_box.dart';

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
      buildWhen: (previous, current) =>
          previous.originName != current.originName ||
          previous.destinationName != current.destinationName,
      builder: (context, state) {
        final originName =
            state.originName ?? tr(LocaleKeys.routing_my_location);
        final destinationName = state.destinationName ??
            tr(LocaleKeys.routing_destination_fallback);

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
                _buildEndpointsRow(
                  context,
                  colorScheme,
                  originName,
                  destinationName,
                  state.isOriginCurrentLocation,
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 8),
                _buildProfileBadge(colorScheme),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEndpointsRow(
    BuildContext context,
    ColorScheme colorScheme,
    String originName,
    String destinationName,
    bool isOriginCurrentLocation,
  ) {
    return Row(
      children: [
        IconButton(
          key: const Key('route_direction_back_btn'),
          icon: const Icon(Icons.arrow_back_rounded, size: 22),
          onPressed: onClose,
          tooltip: tr(LocaleKeys.common_cancel),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RouteEndpointBox(
                icon: Icons.my_location_rounded,
                iconColor: Colors.blueAccent,
                label: originName,
                isDefaultLocation: isOriginCurrentLocation,
                onTap: onSelectOrigin,
              ),
              const SizedBox(height: 6),
              RouteEndpointBox(
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
        IconButton(
          key: const Key('route_direction_swap_btn'),
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
    );
  }

  Widget _buildProfileBadge(ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.25),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.two_wheeler_rounded,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                tr(LocaleKeys.route_drawing_ui_profile_moped),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
