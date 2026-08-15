import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/models/models.dart';

class HomeHeaderSearchBar extends StatelessWidget {
  final double topPadding;
  final ValueChanged<PoiModel> onPoiSelected;
  final ValueChanged<String?> onCategorySelected;

  const HomeHeaderSearchBar({
    super.key,
    required this.topPadding,
    required this.onPoiSelected,
    required this.onCategorySelected,
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
            onPoiSelected: onPoiSelected,
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
