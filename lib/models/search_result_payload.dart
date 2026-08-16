import 'package:equatable/equatable.dart';
import 'package:s_map/models/models.dart';

class SearchResultPayload extends Equatable {
  final PoiModel? selectedPoi;
  final List<PoiModel>? allResults;
  final String? submittedQuery;

  const SearchResultPayload.single(this.selectedPoi)
      : allResults = null,
        submittedQuery = null;

  const SearchResultPayload.all({
    required this.allResults,
    required this.submittedQuery,
  }) : selectedPoi = null;

  bool get isSingle => selectedPoi != null;
  bool get isAll => allResults != null && allResults!.isNotEmpty;

  @override
  List<Object?> get props => [selectedPoi, allResults, submittedQuery];
}
