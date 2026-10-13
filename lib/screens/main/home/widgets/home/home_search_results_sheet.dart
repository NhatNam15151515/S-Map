import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/widgets/search_results_bottom_sheet.dart';
import 'package:s_map/models/models.dart';

/// Home coordinator that provides live location to the reusable sheet.
class HomeSearchResultsSheet extends StatelessWidget {
  final DraggableScrollableController? controller;
  final List<PoiModel> pois;
  final String? query;
  final ValueChanged<PoiModel>? onPoiTap;
  final ValueChanged<PoiModel>? onAddDestination;
  final bool hasExistingDestinations;
  final VoidCallback? onClose;

  const HomeSearchResultsSheet({
    super.key,
    this.controller,
    required this.pois,
    this.query,
    this.onPoiTap,
    this.onAddDestination,
    this.hasExistingDestinations = false,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MapDisplayCubit, MapDisplayState>(
      buildWhen: (previous, current) =>
          previous.currentPosition != current.currentPosition,
      builder: (context, state) => SearchResultsBottomSheet(
        controller: controller,
        pois: pois,
        query: query,
        userLocation: state.currentPosition,
        onPoiTap: onPoiTap,
        onAddDestination: onAddDestination,
        hasExistingDestinations: hasExistingDestinations,
        onClose: onClose,
      ),
    );
  }
}
