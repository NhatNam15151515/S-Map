import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
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
    AppConfirmDialog.show(
      context,
      title: tr(LocaleKeys.route_drawing_ui_delete_confirm_title),
      message: tr(
        LocaleKeys.route_drawing_ui_delete_confirm_desc,
        args: [route.name],
      ),
      confirmText: tr(LocaleKeys.route_drawing_ui_delete_route),
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
      onConfirm: () => context.read<SavedRoutesCubit>().deleteRoute(route.id),
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
                              color:
                                  colorScheme.primary.withValues(alpha: 0.12),
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
                                  style: colorScheme
                                      .onSurface.textTheme.boldStyle
                                      .copyWith(
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${RouteFormatHelper.formatDistance(route.totalDistance)} • ${RouteFormatHelper.formatDuration(route.totalTime)} • ${tr(LocaleKeys.route_drawing_ui_waypoints_count, args: [
                                        route.waypoints.length.toString()
                                      ])}',
                                  style: colorScheme
                                      .onSurfaceVariant.textTheme.textStyle
                                      .copyWith(
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.bookmark_remove_rounded,
                              size: 18,
                              color: colorScheme.error,
                            ),
                            onPressed: () =>
                                _showDeleteConfirmDialog(context, route),
                          ),
                        ],
                      ),
                      if (route.description != null &&
                          route.description!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          route.description!,
                          style: colorScheme
                              .onSurfaceVariant.textTheme.textStyle
                              .copyWith(
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                side: BorderSide(
                                    color: colorScheme.outline.withAlpha(80)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: Icon(Icons.edit_rounded,
                                  size: 16, color: colorScheme.onSurface),
                              label: Text(
                                tr(LocaleKeys.route_drawing_ui_view_drawing),
                                style: colorScheme
                                    .onSurface.textTheme.mediumStyle
                                    .copyWith(fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onPressed: () =>
                                  _onOpenInRouteDrawing(context, route),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.navigation_rounded,
                                  size: 16),
                              label: Text(
                                tr(LocaleKeys.navigation),
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onPressed: () =>
                                  _onStartNavigation(context, route),
                            ),
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
