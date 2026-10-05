import 'package:equatable/equatable.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/models/models.dart';

enum ViewportSearchStatus { initial, loading, success, empty, error }

class ViewportSearchState extends Equatable {
  final ViewportSearchStatus status;
  final List<PoiModel> pois;
  final LatLngBounds? bounds;
  final String selectedCategory;
  final String? errorMessageKey;
  final double? resolvedZoomLevel;
  final LatLng? searchCenter;
  final String? searchQuery;
  final bool fitBoundsMode;
  final bool isAreaSearch;

  const ViewportSearchState({
    this.status = ViewportSearchStatus.initial,
    this.pois = const [],
    this.bounds,
    this.selectedCategory = CategoryConstants.all,
    this.errorMessageKey,
    this.resolvedZoomLevel,
    this.searchCenter,
    this.searchQuery,
    this.fitBoundsMode = false,
    this.isAreaSearch = false,
  });

  bool get isInitial => status == ViewportSearchStatus.initial;
  bool get isLoading => status == ViewportSearchStatus.loading;
  bool get isSuccess => status == ViewportSearchStatus.success;
  bool get isEmpty => status == ViewportSearchStatus.empty;
  bool get isError => status == ViewportSearchStatus.error;
  bool get hasPois => pois.isNotEmpty;

  ViewportSearchState copyWith({
    ViewportSearchStatus? status,
    List<PoiModel>? pois,
    LatLngBounds? bounds,
    String? selectedCategory,
    String? errorMessageKey,
    double? resolvedZoomLevel,
    LatLng? searchCenter,
    String? searchQuery,
    bool? fitBoundsMode,
    bool? isAreaSearch,
    bool clearError = false,
    bool clearBounds = false,
    bool clearResolvedZoomLevel = false,
    bool clearSearchCenter = false,
    bool clearSearchQuery = false,
  }) {
    return ViewportSearchState(
      status: status ?? this.status,
      pois: pois ?? this.pois,
      bounds: clearBounds ? null : (bounds ?? this.bounds),
      selectedCategory: selectedCategory ?? this.selectedCategory,
      errorMessageKey: clearError ? null : (errorMessageKey ?? this.errorMessageKey),
      resolvedZoomLevel: clearResolvedZoomLevel
          ? null
          : (resolvedZoomLevel ?? this.resolvedZoomLevel),
      searchCenter: clearSearchCenter ? null : (searchCenter ?? this.searchCenter),
      searchQuery: clearSearchQuery ? null : (searchQuery ?? this.searchQuery),
      fitBoundsMode: fitBoundsMode ?? this.fitBoundsMode,
      isAreaSearch: isAreaSearch ?? this.isAreaSearch,
    );
  }

  @override
  List<Object?> get props => [
        status,
        pois,
        bounds,
        selectedCategory,
        errorMessageKey,
        resolvedZoomLevel,
        searchCenter,
        searchQuery,
        fitBoundsMode,
        isAreaSearch,
      ];
}
