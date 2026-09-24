import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/screens/main/home/widgets/route_preview/route_preview_action_buttons.dart';
import 'package:s_map/screens/main/home/widgets/route_preview/route_preview_alt_route_selector.dart';
import 'package:s_map/screens/main/home/widgets/route_preview/route_preview_info_header.dart';
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
          RoutePreviewInfoHeader(
            durationStr: durationStr,
            distanceStr: distanceStr,
            etaTimeStr: etaTimeStr,
            state: state,
            onClose: onClose,
          ),
          if (state.hasAlternativeRoutes) ...[
            const SizedBox(height: 12),
            RoutePreviewAltRouteSelector(
              alternativeRoutes: state.alternativeRoutes,
              selectedRouteIndex: state.selectedRouteIndex,
            ),
          ],
          const SizedBox(height: 16),
          RoutePreviewActionButtons(
            onStartNavigation: onStartNavigation,
            onCustomRoute: onCustomRoute,
          ),
        ],
      ),
    );
  }
}
