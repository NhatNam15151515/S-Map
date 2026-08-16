import 'package:equatable/equatable.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/models/models.dart';

enum SearchStatus { initial, loading, success, error }

class SearchState extends Equatable {
  final SearchStatus status;
  final String query;
  final List<PoiModel> results;
  final List<String> suggestions;
  final List<String> recentSearches;
  final LatLng? userLocation;
  final String? errorMessage;

  const SearchState({
    this.status = SearchStatus.initial,
    this.query = '',
    this.results = const [],
    this.suggestions = const [],
    this.recentSearches = const [],
    this.userLocation,
    this.errorMessage,
  });

  bool get isInitial => status == SearchStatus.initial;
  bool get isLoading => status == SearchStatus.loading;
  bool get isSuccess => status == SearchStatus.success;
  bool get isError => status == SearchStatus.error;
  bool get hasResults => results.isNotEmpty;
  bool get isEmptyResults => isSuccess && results.isEmpty;
  bool get hasSuggestions => suggestions.isNotEmpty;

  SearchState copyWith({
    SearchStatus? status,
    String? query,
    List<PoiModel>? results,
    List<String>? suggestions,
    List<String>? recentSearches,
    LatLng? userLocation,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      results: results ?? this.results,
      suggestions: suggestions ?? this.suggestions,
      recentSearches: recentSearches ?? this.recentSearches,
      userLocation: userLocation ?? this.userLocation,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        query,
        results,
        suggestions,
        recentSearches,
        userLocation,
        errorMessage,
      ];
}
