import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/models/models.dart';

import 'package:s_map/routers/routers.dart';
import 'package:s_map/screens/search/widgets/voice_search_bottom_sheet.dart';
import 'package:s_map/screens/main/home/widgets/home/home_profile_avatar.dart';

class HomeHeaderSearchBar extends StatelessWidget {
  final double topPadding;
  final ValueChanged<PoiModel> onPoiSelected;
  final ValueChanged<PoiModel>? onAddDestination;
  final ValueChanged<LatLng> onCurrentLocation;
  final void Function(List<PoiModel> pois, String? query) onSearchResults;
  final ValueChanged<SearchResultPayload>? onAreaSearch;
  final ValueChanged<String?> onCategorySelected;
  final VoidCallback? onSearchOpened;
  final String? activeSearchText;
  final VoidCallback? onClearSearch;

  const HomeHeaderSearchBar({
    super.key,
    required this.topPadding,
    required this.onPoiSelected,
    this.onAddDestination,
    required this.onCurrentLocation,
    required this.onSearchResults,
    this.onAreaSearch,
    required this.onCategorySelected,
    this.onSearchOpened,
    this.activeSearchText,
    this.onClearSearch,
  });

  void _navigateToSearch(BuildContext context, {String? initialQuery}) {
    onSearchOpened?.call();
    final mapState = context.read<MapDisplayCubit>().state;
    final routeState = context.read<RoutePreviewCubit>().state;
    final searchCenter = mapState.currentPosition ?? mapState.center;
    context.push<dynamic>(
      AppRoutes.search,
      extra: SearchScreenArgs(
        userLocation: searchCenter,
        hasExistingDestinations: routeState.destination != null,
        initialQuery: initialQuery,
      ),
    ).then((result) {
      if (result != null && context.mounted) {
        if (result is SearchResultPayload) {
          if (result.isLocation && result.searchCenter != null) {
            onCurrentLocation(result.searchCenter!);
          } else if (result.isAddDestination && result.selectedPoi != null) {
            onAddDestination?.call(result.selectedPoi!);
          } else if (result.isArea) {
            onAreaSearch?.call(result);
          } else if (result.isSingle && result.selectedPoi != null) {
            onPoiSelected(result.selectedPoi!);
          } else if (result.isAll && result.allResults != null) {
            onSearchResults(result.allResults!, result.submittedQuery);
          }
        } else if (result is PoiModel) {
          onPoiSelected(result);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: topPadding + 8,
      left: 16,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MapSearchBar(
            activeSearchText: activeSearchText,
            onClearSearch: onClearSearch,
            onPoiSelected: onPoiSelected,
            onTap: () => _navigateToSearch(context),
            onVoicePressed: () async {
              final query = await showVoiceSearchBottomSheet(context);
              if (query != null && query.isNotEmpty && context.mounted) {
                _navigateToSearch(context, initialQuery: query);
              }
            },
            trailing: const HomeProfileAvatar(),
          ),
          const SizedBox(height: 10),
          BlocBuilder<MapExploreCubit, MapExploreState>(
            buildWhen: (prev, curr) =>
                prev.selectedCategory != curr.selectedCategory,
            builder: (context, exploreState) {
              return MapCategoryChips(
                selectedCategory: exploreState.selectedCategory,
                onCategorySelected: onCategorySelected,
              );
            },
          ),
        ],
      ),
    );
  }
}

