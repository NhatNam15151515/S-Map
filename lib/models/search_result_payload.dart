import 'package:equatable/equatable.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'poi_model.dart';

class SearchResultPayload extends Equatable {
  final PoiModel? selectedPoi;
  final List<PoiModel>? allResults;
  final String? submittedQuery;
  final String? searchCategory;
  final LatLng? searchCenter;
  final bool isAreaSearch;

  const SearchResultPayload.single(this.selectedPoi)
      : allResults = null,
        submittedQuery = null,
        searchCategory = null,
        searchCenter = null,
        isAreaSearch = false;

  const SearchResultPayload.all({
    required this.allResults,
    required this.submittedQuery,
  })  : selectedPoi = null,
        searchCategory = null,
        searchCenter = null,
        isAreaSearch = false;

  const SearchResultPayload.areaSearch({
    this.submittedQuery,
    this.searchCategory,
    this.searchCenter,
  })  : selectedPoi = null,
        allResults = null,
        isAreaSearch = true;

  bool get isSingle => selectedPoi != null;
  bool get isAll => allResults != null && allResults!.isNotEmpty;
  bool get isArea => isAreaSearch;

  @override
  List<Object?> get props => [
        selectedPoi,
        allResults,
        submittedQuery,
        searchCategory,
        searchCenter,
        isAreaSearch,
      ];
}
