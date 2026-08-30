import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/models/models.dart';

class HomeBottomOverlay extends StatelessWidget {
  final DraggableScrollableController sheetController;
  final PoiModel? selectedMarkerPoi;
  final ValueChanged<dynamic> onPlaceTap;
  final VoidCallback onClosePoiCard;
  final VoidCallback onDirections;

  const HomeBottomOverlay({
    super.key,
    required this.sheetController,
    required this.selectedMarkerPoi,
    required this.onPlaceTap,
    required this.onClosePoiCard,
    required this.onDirections,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedMarkerPoi != null) {
      return Positioned(
        left: 0,
        right: 0,
        bottom: 24,
        child: BlocBuilder<MapDisplayCubit, MapDisplayState>(
          buildWhen: (prev, curr) =>
              prev.currentPosition != curr.currentPosition,
          builder: (context, mapDisplayState) {
            return PoiQuickCard(
              poi: selectedMarkerPoi!,
              userLocation: mapDisplayState.currentPosition,
              onClose: onClosePoiCard,
              onDirections: onDirections,
            );
          },
        ),
      );
    }

    return BlocBuilder<MapExploreCubit, MapExploreState>(
      builder: (context, exploreState) {
        return ExploreBottomSheet(
          controller: sheetController,
          places: exploreState.places,
          isLoading: exploreState.isLoading,
          onPlaceTap: onPlaceTap,
        );
      },
    );
  }
}
