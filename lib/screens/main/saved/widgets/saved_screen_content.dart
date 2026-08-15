import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';
import 'saved_poi_card.dart';

class SavedScreenContent extends StatelessWidget {
  const SavedScreenContent({super.key});

  void _onPoiTap(BuildContext context, PoiModel poi) {
    try {
      context.read<MapDisplayCubit>().selectPoi(poi);
    } catch (_) {}
    context.go('/HomeScreen');
  }

  void _onDirections(PoiModel poi) {
    AppUtils.instance.openLocation(poi.lat, poi.lon);
  }

  void _onRemoveFavorite(BuildContext context, PoiModel poi) {
    final cubit = context.read<FavoritesCubit>();
    final key = cubit.getPoiKey(poi);
    cubit.removeFavorite(key);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FavoritesCubit, FavoritesState>(
      builder: (context, state) {
        if (state.isLoading && state.favorites.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: DefaultListingShimmer(),
          );
        }

        if (state.favorites.isEmpty) {
          return EmptyWidget(
            title: tr(LocaleKeys.noSavedPlaces),
            subtitle: tr(LocaleKeys.savePlacesSubtitle),
            icon: Icons.bookmark_border_rounded,
          );
        }

        return RefreshIndicator(
          onRefresh: () => context.read<FavoritesCubit>().loadFavorites(),
          color: AppColors.sMapTeal,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: state.favorites.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final poi = state.favorites[index];
              return SavedPoiCard(
                poi: poi,
                onTap: () => _onPoiTap(context, poi),
                onDirections: () => _onDirections(poi),
                onRemove: () => _onRemoveFavorite(context, poi),
              );
            },
          ),
        );
      },
    );
  }
}
