import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/models/models.dart';

import 'package:s_map/routers/routers.dart';

class HomeHeaderSearchBar extends StatelessWidget {
  final double topPadding;
  final ValueChanged<PoiModel> onPoiSelected;
  final void Function(List<PoiModel> pois, String? query) onSearchResults;
  final ValueChanged<String?> onCategorySelected;
  final String? activeSearchText;
  final VoidCallback? onClearSearch;

  const HomeHeaderSearchBar({
    super.key,
    required this.topPadding,
    required this.onPoiSelected,
    required this.onSearchResults,
    required this.onCategorySelected,
    this.activeSearchText,
    this.onClearSearch,
  });

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
            onTap: () {
              final mapState = context.read<MapDisplayCubit>().state;
              // Ưu tiên GPS để kết quả gần người dùng. Khi GPS chưa sẵn
              // sàng, dùng tâm camera hiện tại thay vì tìm toàn bộ dữ liệu.
              final searchCenter = mapState.currentPosition ?? mapState.center;
              context.push<dynamic>(
                AppRoutes.search,
                extra: searchCenter,
              ).then((result) {
                if (result != null && context.mounted) {
                  if (result is SearchResultPayload) {
                    if (result.isSingle && result.selectedPoi != null) {
                      onPoiSelected(result.selectedPoi!);
                    } else if (result.isAll && result.allResults != null) {
                      onSearchResults(result.allResults!, result.submittedQuery);
                    }
                  } else if (result is PoiModel) {
                    onPoiSelected(result);
                  }
                }
              });
            },
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

