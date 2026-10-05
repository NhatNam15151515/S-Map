import 'package:equatable/equatable.dart';
import 'package:s_map/models/models.dart';

enum FavoritesStatus { initial, loading, success, error }

class FavoritesState extends Equatable {
  final FavoritesStatus status;
  final List<PoiModel> favorites;
  final Set<String> favoriteIds;
  final String? errorMessage;

  const FavoritesState({
    this.status = FavoritesStatus.initial,
    this.favorites = const [],
    this.favoriteIds = const {},
    this.errorMessage,
  });

  bool isFavorite(String poiId) => favoriteIds.contains(poiId);

  bool get isInitial => status == FavoritesStatus.initial;
  bool get isLoading => status == FavoritesStatus.loading;
  bool get isSuccess => status == FavoritesStatus.success;
  bool get isError => status == FavoritesStatus.error;

  FavoritesState copyWith({
    FavoritesStatus? status,
    List<PoiModel>? favorites,
    Set<String>? favoriteIds,
    String? errorMessage,
    bool clearError = false,
  }) {
    return FavoritesState(
      status: status ?? this.status,
      favorites: favorites ?? this.favorites,
      favoriteIds: favoriteIds ?? this.favoriteIds,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, favorites, favoriteIds, errorMessage];
}
