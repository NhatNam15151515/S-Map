import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/transformers/transformers.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/repos/repos.dart';
import 'viewport_search_event.dart';
import 'viewport_search_state.dart';

class ViewportSearchBloc
    extends Bloc<ViewportSearchEvent, ViewportSearchState> {
  final IPoiRepository _poiRepository;
  String _currentCategory = CategoryConstants.all;
  int _queryGeneration = 0;
  DateTime? _lastClearedAt;

  String get currentCategory => _currentCategory;

  ViewportSearchBloc({IPoiRepository? poiRepository})
      : _poiRepository = poiRepository ?? PoiRepositoryImpl(),
        super(const ViewportSearchState()) {
    on<SearchInViewportRequested>(
      _onSearchInViewport,
      transformer: debounceRestartable(const Duration(milliseconds: 250)),
    );

    on<SearchThisAreaPressed>(
      _onSearchThisArea,
      transformer: restartable(),
    );

    on<ViewportCategoryFilterChanged>(
      _onCategoryFilterChanged,
      transformer: restartable(),
    );

    on<ClearViewportSearch>(_onClearViewportSearch);
  }

  Future<void> _onSearchInViewport(
    SearchInViewportRequested event,
    Emitter<ViewportSearchState> emit,
  ) async {
    if (_lastClearedAt != null && !event.createdAt.isAfter(_lastClearedAt!)) {
      return;
    }

    await _executeViewportQuery(
      emit: emit,
      bounds: event.bounds,
      category: event.category ?? _currentCategory,
      query: event.query,
      limit: event.limit,
    );
  }

  Future<void> _onSearchThisArea(
    SearchThisAreaPressed event,
    Emitter<ViewportSearchState> emit,
  ) async {
    await _executeViewportQuery(
      emit: emit,
      bounds: event.bounds,
      category: event.category ?? _currentCategory,
      query: event.query,
      limit: event.limit,
    );
  }

  Future<void> _onCategoryFilterChanged(
    ViewportCategoryFilterChanged event,
    Emitter<ViewportSearchState> emit,
  ) async {
    _currentCategory = event.category;

    if (event.bounds != null) {
      await _executeViewportQuery(
        emit: emit,
        bounds: event.bounds!,
        category: _currentCategory,
        query: null,
        limit: 50,
      );
    }
  }

  void _onClearViewportSearch(
    ClearViewportSearch event,
    Emitter<ViewportSearchState> emit,
  ) {
    _queryGeneration++;
    _lastClearedAt = DateTime.now();
    _currentCategory = CategoryConstants.all;
    emit(const ViewportSearchState());
  }

  Future<void> _executeViewportQuery({
    required Emitter<ViewportSearchState> emit,
    required LatLngBounds bounds,
    required String category,
    String? query,
    required int limit,
  }) async {
    final gen = ++_queryGeneration;
    emit(state.copyWith(
      status: ViewportSearchStatus.loading,
      bounds: bounds,
      selectedCategory: category,
      clearError: true,
    ));

    try {
      final double minLat = bounds.southwest.latitude < bounds.northeast.latitude
          ? bounds.southwest.latitude
          : bounds.northeast.latitude;
      final double maxLat = bounds.southwest.latitude > bounds.northeast.latitude
          ? bounds.southwest.latitude
          : bounds.northeast.latitude;
      final double minLon = bounds.southwest.longitude < bounds.northeast.longitude
          ? bounds.southwest.longitude
          : bounds.northeast.longitude;
      final double maxLon = bounds.southwest.longitude > bounds.northeast.longitude
          ? bounds.southwest.longitude
          : bounds.northeast.longitude;

      final pois = await _poiRepository.searchInBounds(
        minLat: minLat,
        maxLat: maxLat,
        minLon: minLon,
        maxLon: maxLon,
        query: query,
        category: category.isNotEmpty && category != CategoryConstants.all
            ? category
            : null,
        limit: limit,
      );

      // Guard: kiểm tra emitter hoặc generation có bị hủy trước khi emit
      if (emit.isDone || gen != _queryGeneration) return;

      if (pois.isEmpty) {
        emit(state.copyWith(
          status: ViewportSearchStatus.empty,
          pois: const [],
          bounds: bounds,
          selectedCategory: category,
          clearError: true,
        ));
      } else {
        emit(state.copyWith(
          status: ViewportSearchStatus.success,
          pois: pois,
          bounds: bounds,
          selectedCategory: category,
          clearError: true,
        ));
      }
    } catch (_) {
      if (emit.isDone || gen != _queryGeneration) return;
      emit(state.copyWith(
        status: ViewportSearchStatus.error,
        errorMessageKey: LocaleKeys.no_pois_in_viewport,
        bounds: bounds,
      ));
    }
  }
}
