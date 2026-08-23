import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:heroicons/heroicons.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
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
      builder: (sheetCtx) => BlocProvider.value(
        value: context.read<SavedRoutesCubit>(),
        child: SavedRoutesSheet(
          onRouteSelected: (route) {
            Navigator.of(sheetCtx).pop();
            onRouteSelected(route);
          },
          onRouteDeleted: onRouteDeleted,
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, CustomRouteModel route) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          tr(LocaleKeys.route_drawing_ui_delete_confirm_title),
          style: AppStyle.of(context).blackTextColor.textTheme.boldStyle.copyWith(
                fontSize: 16,
              ),
        ),
        content: Text(
          tr(LocaleKeys.route_drawing_ui_delete_confirm_desc, args: [route.name]),
          style: AppStyle.of(context).blackTextColor.textTheme.textStyle.copyWith(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(
              tr(LocaleKeys.cancel),
              style: const TextStyle(color: AppColors.grey),
            ),
          ),
          ElevatedButton(
            key: const Key('delete_saved_route_confirm_btn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.heroicRed,
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
              style: const TextStyle(color: AppColors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: AppColors.white,
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
                color: AppColors.plaster,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          const SizedBox(height: 16),
          // Title
          Row(
            children: [
              const HeroIcon(
                HeroIcons.bookmark,
                size: 22,
                color: AppColors.sMapTeal,
              ),
              const SizedBox(width: 8),
              Text(
                tr(LocaleKeys.route_drawing_ui_saved_routes_title),
                style: style.blackTextColor.textTheme.boldStyle.copyWith(
                  fontSize: 18,
                  color: AppColors.grimReaper,
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
                          decoration: const BoxDecoration(
                            color: AppColors.sMapLightTeal,
                            shape: BoxShape.circle,
                          ),
                          child: const HeroIcon(
                            HeroIcons.mapPin,
                            size: 32,
                            color: AppColors.sMapTeal,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          tr(LocaleKeys.route_drawing_ui_no_saved_routes),
                          style: style.blackTextColor.textTheme.boldStyle.copyWith(
                            fontSize: 16,
                            color: AppColors.grimReaper,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr(LocaleKeys.route_drawing_ui_no_saved_routes_desc),
                          style: style.blackTextColor.textTheme.textStyle.copyWith(
                            fontSize: 13,
                            color: AppColors.sonicSilver,
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
                  separatorBuilder: (context, index) => const Divider(height: 16),
                  itemBuilder: (context, index) {
                    final route = state.routes[index];
                    final distanceKm = route.totalDistance / 1000.0;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        route.name,
                        style: style.blackTextColor.textTheme.boldStyle.copyWith(
                          fontSize: 15,
                          color: AppColors.grimReaper,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${distanceKm.toStringAsFixed(1)} km • ${route.waypoints.length} waypoints',
                          style: style.blackTextColor.textTheme.textStyle.copyWith(
                            fontSize: 12,
                            color: AppColors.sonicSilver,
                          ),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const HeroIcon(
                              HeroIcons.arrowDownTray,
                              size: 20,
                              color: AppColors.sMapTeal,
                            ),
                            tooltip: tr(LocaleKeys.route_drawing_ui_load_route),
                            onPressed: () => onRouteSelected(route),
                          ),
                          IconButton(
                            icon: const HeroIcon(
                              HeroIcons.trash,
                              size: 20,
                              color: AppColors.roughStone,
                            ),
                            tooltip: tr(LocaleKeys.route_drawing_ui_delete_route),
                            onPressed: () => _showDeleteConfirmDialog(context, route),
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
