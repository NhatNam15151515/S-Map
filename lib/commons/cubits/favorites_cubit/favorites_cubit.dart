import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'favorites_fallbacks.dart';
import 'favorites_state.dart';

class FavoritesCubit extends Cubit<FavoritesState> {
  final IFavoritesService _favoritesService;

  /// Optional global default service resolver set during app bootstrap
  static IFavoritesService? defaultFavoritesService;

  FavoritesCubit({IFavoritesService? favoritesService})
      : _favoritesService = favoritesService ??
            defaultFavoritesService ??
            NoOpFavoritesService(),
        super(const FavoritesState()) {
    loadFavorites();
  }

  @override
  void emit(FavoritesState state) {
    if (isClosed) return;
    super.emit(state);
  }

  String getPoiKey(PoiModel poi) => PoiCategoryHelper.getPoiKey(poi);

  Future<void> removeFavoritePoi(PoiModel poi) async {
    await removeFavorite(getPoiKey(poi));
  }

  Future<void> loadFavorites() async {
    emit(state.copyWith(status: FavoritesStatus.loading, clearError: true));
    try {
      final items = await _favoritesService.getFavorites();
      final ids = items.map((p) => getPoiKey(p)).toSet();
      emit(state.copyWith(
        status: FavoritesStatus.success,
        favorites: items,
        favoriteIds: ids,
        clearError: true,
      ));
    } catch (e) {
      DLog.error('Lỗi tải danh sách favorites: $e');
      emit(state.copyWith(
        status: FavoritesStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> toggleFavorite(PoiModel poi) async {
    final key = getPoiKey(poi);
    final isFav = state.isFavorite(key);

    try {
      if (isFav) {
        await _favoritesService.removeFavorite(key);
        final updatedList =
            state.favorites.where((p) => getPoiKey(p) != key).toList();
        final updatedIds = Set<String>.from(state.favoriteIds)..remove(key);

        emit(state.copyWith(
          favorites: updatedList,
          favoriteIds: updatedIds,
          clearError: true,
        ));
      } else {
        await _favoritesService.addFavorite(poi);
        final updatedList = [poi, ...state.favorites];
        final updatedIds = Set<String>.from(state.favoriteIds)..add(key);

        emit(state.copyWith(
          favorites: updatedList,
          favoriteIds: updatedIds,
          clearError: true,
        ));
      }
    } catch (e) {
      DLog.error('Lỗi toggle favorite: $e');
      emit(state.copyWith(
        status: FavoritesStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> removeFavorite(String poiId) async {
    try {
      await _favoritesService.removeFavorite(poiId);
      final updatedList =
          state.favorites.where((p) => getPoiKey(p) != poiId).toList();
      final updatedIds = Set<String>.from(state.favoriteIds)..remove(poiId);

      emit(state.copyWith(
        favorites: updatedList,
        favoriteIds: updatedIds,
        clearError: true,
      ));
    } catch (e) {
      DLog.error('Lỗi xóa favorite: $e');
      emit(state.copyWith(
        status: FavoritesStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> clearFavorites() async {
    try {
      await _favoritesService.clearFavorites();
      emit(state.copyWith(
        favorites: const [],
        favoriteIds: const {},
        clearError: true,
      ));
    } catch (e) {
      DLog.error('Lỗi dọn sạch favorites: $e');
      emit(state.copyWith(
        status: FavoritesStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }
}
