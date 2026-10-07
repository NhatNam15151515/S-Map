import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/routers/app_routes.dart';
import 'saved_route_card.dart';

class SavedRoutesTabContent extends StatelessWidget {
  const SavedRoutesTabContent({super.key});

  void _onStartNavigation(BuildContext context, CustomRouteModel route) {
    final rawPoints = route.fullPolyline;
    final customName = route.name.isNotEmpty
        ? route.name
        : tr(LocaleKeys.route_drawing_ui_custom_route_name);
    final followInstruction = tr(
      LocaleKeys.route_drawing_ui_follow_custom_route,
    );
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

    final originWaypoint = route.waypoints.first;
    final originPoint = RoutePoint(
      lat: originWaypoint.originalLat,
      lon: originWaypoint.originalLon,
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
          originName: originWaypoint.displayName.trim().isNotEmpty
              ? originWaypoint.displayName.trim()
              : originWaypoint.streetName.trim().isNotEmpty
              ? originWaypoint.streetName.trim()
              : null,
          destination: destPoint,
          destinationName: customName,
        ),
      );
    } catch (_) {}

    context.go(AppRoutes.home);
  }

  void _onOpenInRouteDrawing(BuildContext context, CustomRouteModel route) {
    context.go(AppRoutes.home, extra: RouteDrawingPayload(initialRoute: route));
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
              return SavedRouteCard(
                route: route,
                onViewDrawing: () => _onOpenInRouteDrawing(context, route),
                onStartNavigation: () => _onStartNavigation(context, route),
                onDelete: () => _showDeleteConfirmDialog(context, route),
              );
            },
          ),
        );
      },
    );
  }
}
