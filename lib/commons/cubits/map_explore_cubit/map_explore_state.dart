import 'package:equatable/equatable.dart';
import 'package:s_map/constants/category_constants.dart';
import 'package:s_map/models/place_model.dart';

enum MapExploreStatus { initial, loading, loaded, error }

class MapExploreState extends Equatable {
  final MapExploreStatus status;
  final List<PlaceModel> places;
  final String selectedCategory;
  final String? errorMessage;

  const MapExploreState({
    this.status = MapExploreStatus.initial,
    this.places = const [],
    this.selectedCategory = CategoryConstants.all,
    this.errorMessage,
  });

  bool get isLoading => status == MapExploreStatus.loading;

  MapExploreState copyWith({
    MapExploreStatus? status,
    List<PlaceModel>? places,
    String? selectedCategory,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MapExploreState(
      status: status ?? this.status,
      places: places ?? this.places,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, places, selectedCategory, errorMessage];
}
