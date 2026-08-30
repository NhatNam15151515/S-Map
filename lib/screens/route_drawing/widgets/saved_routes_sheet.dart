import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';

class SavedRoutesSheet extends StatelessWidget {
  final ValueChanged<CustomRouteModel> onRouteSelected;
  final ValueChanged<String> onRouteDeleted;

  const SavedRoutesSheet({
    super.key,
    required this.onRouteSelected,
    required this.onRouteDeleted,
  });

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<CustomRouteModel> onRouteSelected,
    required ValueChanged<String> onRouteDeleted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BlocProvider.value(
        value: context.read<SavedRoutesCubit>(),
        child: SavedRoutesSheet(
          onRouteSelected: (route) {
            ctx.pop();
            onRouteSelected(route);
          },
          onRouteDeleted: onRouteDeleted,
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, CustomRouteModel route) {
    final colorScheme = Theme.of(context).colorScheme;
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
          tr(LocaleKeys.route_drawing_ui_delete_confirm_desc,
              args: [route.name]),
          style: colorScheme.onSurfaceVariant.textTheme.textStyle
              .copyWith(fontSize: 14),
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
            key: const Key('delete_saved_route_confirm_btn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              onRouteDeleted(route.id);
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
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: bottomPadding + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outline.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // Title
            Row(
              children: [
                HeroIcon(
                  HeroIcons.bookmark,
                  size: 22,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  tr(LocaleKeys.route_drawing_ui_saved_routes_title),
                  style: colorScheme.onSurface.textTheme.boldStyle.copyWith(
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // List content
            Expanded(
              child: BlocBuilder<SavedRoutesCubit, SavedRoutesState>(
                builder: (context, state) {
                  if (state.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state.routes.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withAlpha(30),
                              shape: BoxShape.circle,
                            ),
                            child: HeroIcon(
                              HeroIcons.mapPin,
                              size: 32,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            tr(LocaleKeys.route_drawing_ui_no_saved_routes),
                            style: colorScheme.onSurface.textTheme.boldStyle
                                .copyWith(
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tr(LocaleKeys
                                .route_drawing_ui_no_saved_routes_desc),
                            style: colorScheme
                                .onSurfaceVariant.textTheme.textStyle
                                .copyWith(
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    key: const Key('saved_routes_list_view'),
                    itemCount: state.routes.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 16,
                      color: colorScheme.outline.withAlpha(40),
                    ),
                    itemBuilder: (context, index) {
                      final route = state.routes[index];
                      final distanceKm = route.totalDistance / 1000.0;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          route.name,
                          style: colorScheme.onSurface.textTheme.boldStyle
                              .copyWith(
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${distanceKm.toStringAsFixed(1)} km • ${tr(LocaleKeys.route_drawing_ui_waypoints_count, args: [
                                  route.waypoints.length.toString()
                                ])}',
                            style: colorScheme
                                .onSurfaceVariant.textTheme.textStyle
                                .copyWith(
                              fontSize: 12,
                            ),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: HeroIcon(
                                HeroIcons.arrowDownTray,
                                size: 20,
                                color: colorScheme.primary,
                              ),
                              tooltip:
                                  tr(LocaleKeys.route_drawing_ui_load_route),
                              onPressed: () => onRouteSelected(route),
                            ),
                            IconButton(
                              key: Key('delete_saved_route_${route.id}'),
                              icon: HeroIcon(
                                HeroIcons.trash,
                                size: 20,
                                color: colorScheme.outline.withAlpha(150),
                              ),
                              tooltip:
                                  tr(LocaleKeys.route_drawing_ui_delete_route),
                              onPressed: () =>
                                  _showDeleteConfirmDialog(context, route),
                            ),
                          ],
                        ),
                        onTap: () => onRouteSelected(route),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
