import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/routers/app_routes.dart';

class SavedRoutesTabContent extends StatelessWidget {
  const SavedRoutesTabContent({super.key});

  void _onStartNavigation(BuildContext context, CustomRouteModel route) {
    final rawPoints = route.fullPolyline;
    final customName = route.name.isNotEmpty
        ? route.name
        : tr(LocaleKeys.route_drawing_ui_custom_route_name);
    final followInstruction =
        tr(LocaleKeys.route_drawing_ui_follow_custom_route);
    final instructions = <RouteInstruction>[
      RouteInstruction(
        text: followInstruction,
        streetName: customName,
        distance: route.totalDistance,
        time: route.totalTime,
        sign: 0,
        points: rawPoints,
      ),
    ];

    final customRoute = RouteResult(
      isSuccess: true,
      distance: route.totalDistance,
      time: route.totalTime,
      points: rawPoints,
      instructions: instructions,
    );

    final originPoint = RoutePoint(
      lat: route.waypoints.first.snappedLat,
      lon: route.waypoints.first.snappedLon,
    );
    final destPoint = RoutePoint(
      lat: route.waypoints.last.snappedLat,
      lon: route.waypoints.last.snappedLon,
    );

    try {
      context.read<NavigationBloc>().add(
        StartNavigation(
          initialRoute: customRoute,
          origin: originPoint,
          destination: destPoint,
          destinationName: customName,
        ),
      );
    } catch (_) {}

    context.go(AppRoutes.home);
  }

  void _onOpenInRouteDrawing(BuildContext context, CustomRouteModel route) {
    context.push(
      AppRoutes.routeDrawing,
      extra: RouteDrawingPayload(initialRoute: route),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, CustomRouteModel route) {
    final colorScheme = context.colorScheme;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          tr(LocaleKeys.route_drawing_ui_delete_confirm_title),
          style: colorScheme.onSurface.textTheme.boldStyle.copyWith(
            fontSize: 16,
          ),
        ),
        content: Text(
          tr(
            LocaleKeys.route_drawing_ui_delete_confirm_desc,
            args: [route.name],
          ),
          style: colorScheme.onSurfaceVariant.textTheme.textStyle.copyWith(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => dialogCtx.safePop(),
            child: Text(
              tr(LocaleKeys.cancel),
              style: colorScheme.onSurfaceVariant.textTheme.mediumStyle,
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              dialogCtx.safePop();
              context.read<SavedRoutesCubit>().deleteRoute(route.id);
            },
            child: Text(
              tr(LocaleKeys.route_drawing_ui_delete_route),
              style: colorScheme.onError.textTheme.boldStyle,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return BlocBuilder<SavedRoutesCubit, SavedRoutesState>(
      builder: (context, state) {
        if (state.isLoading && state.routes.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: DefaultListingShimmer(),
          );
        }

        if (state.routes.isEmpty) {
          return EmptyWidget(
            title: tr(LocaleKeys.route_drawing_ui_no_saved_routes),
            subtitle: tr(LocaleKeys.route_drawing_ui_no_saved_routes_desc),
            icon: Icons.gesture_rounded,
          );
        }

        return RefreshIndicator(
          onRefresh: () => context.read<SavedRoutesCubit>().loadSavedRoutes(),
          color: colorScheme.primary,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: state.routes.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final route = state.routes[index];
              final distanceKm = route.totalDistance / 1000.0;
              final durationMinutes = (route.totalTime / 60000.0).round();

              return Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outline.withAlpha(50),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.alt_route_rounded,
                              color: colorScheme.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  route.name,
                                  style: colorScheme.onSurface.textTheme.boldStyle.copyWith(
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${distanceKm.toStringAsFixed(1)} km • $durationMinutes phút • ${route.waypoints.length} điểm',
                                  style: colorScheme.onSurfaceVariant.textTheme.textStyle.copyWith(
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: HeroIcon(
                              HeroIcons.trash,
                              size: 18,
                              color: colorScheme.outline.withAlpha(150),
                            ),
                            onPressed: () => _showDeleteConfirmDialog(context, route),
                          ),
                        ],
                      ),
                      if (route.description != null && route.description!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          route.description!,
                          style: colorScheme.onSurfaceVariant.textTheme.textStyle.copyWith(
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              side: BorderSide(color: colorScheme.outline.withAlpha(80)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: Icon(Icons.edit_rounded, size: 16, color: colorScheme.onSurface),
                            label: Text(
                              'Xem bản vẽ',
                              style: colorScheme.onSurface.textTheme.mediumStyle.copyWith(fontSize: 13),
                            ),
                            onPressed: () => _onOpenInRouteDrawing(context, route),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.navigation_rounded, size: 16),
                            label: const Text(
                              'Dẫn đường',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            onPressed: () => _onStartNavigation(context, route),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
