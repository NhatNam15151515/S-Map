import 'package:flutter/material.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/main/home/widgets/home/home_search_results_sheet.dart';

/// Owns navigation/modal behavior for search results shown by Home.
class HomeSearchResultsCoordinator {
  static Future<SearchResultPayload?> showSheet(
    BuildContext context, {
    required List<PoiModel> pois,
    String? query,
    bool hasExistingDestinations = false,
  }) {
    return showModalBottomSheet<SearchResultPayload>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => HomeSearchResultsSheet(
        pois: pois,
        query: query,
        hasExistingDestinations: hasExistingDestinations,
        onPoiTap: (poi) => Navigator.of(sheetContext).pop(
          SearchResultPayload.single(poi),
        ),
        onAddDestination: (poi) => Navigator.of(sheetContext).pop(
          SearchResultPayload.addDestination(poi),
        ),
      ),
    );
  }

  static Future<SearchResultPayload?> resolvePayload(
    BuildContext context,
    dynamic result, {
    required bool hasExistingDestinations,
  }) async {
    if (result is SearchResultPayload) {
      if (!result.isAll ||
          result.allResults == null ||
          result.allResults!.isEmpty) {
        return result;
      }
      return showSheet(
        context,
        pois: result.allResults!,
        query: result.submittedQuery,
        hasExistingDestinations: hasExistingDestinations,
      );
    }

    if (result is PoiModel) return SearchResultPayload.single(result);
    return null;
  }
}
