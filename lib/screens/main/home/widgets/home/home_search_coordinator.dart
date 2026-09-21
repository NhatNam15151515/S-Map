import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/main/home/widgets/home/home_interactive_map_layer.dart';

/// Coordinator quản lý toàn bộ logic tìm kiếm trên Home Screen.
///
/// Trách nhiệm:
/// - Tìm kiếm theo danh mục (category)
/// - Tìm kiếm khu vực (area search)
/// - "Tìm kiếm khu vực này" (search this area)
/// - Xử lý kết quả tìm kiếm
/// - Xóa tìm kiếm
class HomeSearchCoordinator {
  final GlobalKey<HomeInteractiveMapLayerState> mapLayerKey;
  final MapDisplayCubit displayCubit;
  final MapExploreCubit exploreCubit;
  final ViewportSearchBloc viewportBloc;
  final VoidCallback onStateChanged;

  // State được quản lý bởi coordinator
  List<PoiModel> searchResults = [];
  String? activeSearchText;
  bool showSearchThisArea = false;

  HomeSearchCoordinator({
    required this.mapLayerKey,
    required this.displayCubit,
    required this.exploreCubit,
    required this.viewportBloc,
    required this.onStateChanged,
  });

  void handleCategorySelected(String? cat) {
    if (cat == null) return;
    if (activeSearchText != null &&
        exploreCubit.state.selectedCategory == cat) {
      handleClearSearch();
      return;
    }
    final categoryTitle = tr(PoiCategoryHelper.getCategoryLocaleKey(cat));
    exploreCubit.selectCategory(cat);
    _startAreaSearch(category: cat, label: categoryTitle);
  }

  void handleAreaSearch(SearchResultPayload payload) {
    final category = payload.searchCategory?.trim().toLowerCase();
    final normalizedCategory =
        category == null || category.isEmpty ? CategoryConstants.all : category;
    final query = payload.submittedQuery?.trim();
    final label = normalizedCategory == CategoryConstants.all
        ? query
        : tr(PoiCategoryHelper.getCategoryLocaleKey(normalizedCategory));

    exploreCubit.selectCategory(normalizedCategory);
    _startAreaSearch(
      category: normalizedCategory == CategoryConstants.all
          ? null
          : normalizedCategory,
      query: normalizedCategory == CategoryConstants.all ? query : null,
      center: payload.searchCenter,
      label: label,
    );
  }

  void _startAreaSearch({
    String? category,
    String? query,
    LatLng? center,
    String? label,
  }) {
    final mapState = displayCubit.state;
    final searchCenter = center ??
        mapState.currentPosition ??
        mapState.center ??
        MapConstants.defaultLocation;

    mapLayerKey.currentState?.clearAll();
    displayCubit.clearSelectedPoi();
    viewportBloc.add(
      ProgressiveAreaSearch(
        center: searchCenter,
        category: category,
        query: query,
      ),
    );
    activeSearchText = label;
    searchResults = [];
    showSearchThisArea = false;
    onStateChanged();
  }

  void handleSearchThisArea() {
    mapLayerKey.currentState?.clearAll();
    displayCubit.clearSelectedPoi();
    searchResults = [];
    showSearchThisArea = false;
    onStateChanged();

    final isCategorySearch =
        exploreCubit.state.selectedCategory != CategoryConstants.all;
    mapLayerKey.currentState?.searchThisArea(
      query: isCategorySearch ? null : activeSearchText,
    );
  }

  /// Xử lý danh sách kết quả tìm kiếm từ ViewportSearchBloc.
  ///
  /// Trả về POI nếu chỉ có 1 kết quả (cần select marker bên ngoài).
  PoiModel? handleSearchResults(
    List<PoiModel> pois,
    String? query,
  ) {
    if (pois.isEmpty) {
      mapLayerKey.currentState?.clearAll();
      displayCubit.clearSelectedPoi();
      searchResults = [];
      activeSearchText = query;
      showSearchThisArea = false;
      onStateChanged();
      return null;
    }
    if (pois.length == 1) {
      searchResults = pois;
      onStateChanged();
      mapLayerKey.currentState?.cacheSearchResultPois(pois);
      return pois.first;
    }
    mapLayerKey.currentState?.showSearchResults(pois, fitBounds: true);
    searchResults = pois;
    activeSearchText = query;
    showSearchThisArea = false;
    onStateChanged();
    return null;
  }

  void handleClearSearch() {
    mapLayerKey.currentState?.clearAll();
    displayCubit.clearSelectedPoi();
    exploreCubit.selectCategory(CategoryConstants.all);
    viewportBloc.add(const ClearViewportSearch());
    searchResults = [];
    activeSearchText = null;
    showSearchThisArea = false;
    onStateChanged();
  }

  void handleCloseSearchResults() {
    handleClearSearch();
  }
}
