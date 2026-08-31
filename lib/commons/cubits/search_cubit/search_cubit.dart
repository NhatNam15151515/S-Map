import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/commons/validators/validator.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/repos/repos.dart';
import 'search_fallbacks.dart';
import 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  final IPoiRepository _poiRepository;
  final IRecentSearchService _recentSearchService;

  Timer? _debounceTimer;
  static const Duration defaultDebounceDuration = Duration(milliseconds: 300);

  // Tìm gần trước, sau đó mới mở rộng dần nếu khu vực hiện tại không có
  // kết quả. Mốc cuối đủ lớn để bao phủ toàn bộ dataset Việt Nam.
  static const List<double> nearbySearchRadiusStepsKm = [
    8.0,
    20.0,
    50.0,
    100.0,
    250.0,
    500.0,
    1000.0,
    2500.0,
  ];

  /// Optional global default service resolver set by the app shell
  static IRecentSearchService? defaultRecentSearchService;

  SearchCubit({
    IPoiRepository? poiRepository,
    IRecentSearchService? recentSearchService,
    LatLng? userLocation,
  })  : _poiRepository = poiRepository ?? PoiRepositoryImpl(),
        _recentSearchService = recentSearchService ??
            defaultRecentSearchService ??
            NoOpRecentSearchService(),
        super(SearchState(userLocation: userLocation));

  /// Cập nhật vị trí GPS người dùng để tính khoảng cách tới các POI
  void updateUserLocation(LatLng location) {
    final sortedResults =
        PoiCategoryHelper.sortPoisByDistance(state.results, location);
    emit(state.copyWith(
      userLocation: location,
      results: sortedResults,
    ));
  }

  @override
  void emit(SearchState state) {
    if (isClosed) return;
    super.emit(state);
  }

  /// Xử lý khi người dùng gõ vào SearchBar với cơ chế Debounce 300ms
  void onQueryChanged(String query, {Duration? debounceDuration}) {
    _debounceTimer?.cancel();

    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      emit(state.copyWith(
        status: SearchStatus.initial,
        query: '',
        results: const [],
        suggestions: const [],
        clearError: true,
      ));
      return;
    }

    // Cập nhật query ngay lập tức để chặn các request cũ ghi đè state
    emit(state.copyWith(query: cleanQuery));

    _debounceTimer = Timer(
      debounceDuration ?? defaultDebounceDuration,
      () => _fetchSuggestionsAndResults(cleanQuery),
    );
  }

  /// Tải song song cả danh sách Gợi ý (Suggestions) và Kết quả tìm kiếm (Results)
  Future<void> _fetchSuggestionsAndResults(String query) async {
    if (isClosed) return;
    if (!Validator.instance.isValidSearchQuery(query)) {
      emit(state.copyWith(
        status: SearchStatus.initial,
        query: query,
        results: const [],
        suggestions: const [],
        clearError: true,
      ));
      return;
    }

    emit(state.copyWith(
      status: SearchStatus.loading,
      query: query,
    ));

    try {
      final resultsFuture = _searchInCurrentArea(query);
      final dbSuggestionsFuture = _poiRepository.getSuggestions(query);

      final results = await resultsFuture;
      final dbSuggestions = await dbSuggestionsFuture;

      // Đảm bảo kết quả phản hồi khớp với query hiện tại, tránh race condition
      if (state.query != query || isClosed) return;

      // Sắp xếp kết quả đề xuất theo khoảng cách gần nhất
      final sortedResults =
          PoiCategoryHelper.sortPoisByDistance(results, state.userLocation);

      // Lọc các từ khóa trong Recent Searches khớp với query (chuyển về toLowerCase)
      final asciiQuery = AppUtils.instance.toAscii(query).toLowerCase();
      final matchedRecents = state.recentSearches.where((recent) {
        final asciiRecent = AppUtils.instance.toAscii(recent).toLowerCase();
        return asciiRecent.contains(asciiQuery);
      }).toList();

      // Hợp nhất gợi ý: Ưu tiên Recent Search -> Gợi ý từ POI Database
      final mergedSuggestions = <String>[];
      final seen = <String>{};

      for (final s in matchedRecents) {
        final lower = s.toLowerCase();
        if (seen.add(lower)) {
          mergedSuggestions.add(s);
        }
      }

      for (final s in dbSuggestions) {
        final lower = s.toLowerCase();
        if (seen.add(lower)) {
          mergedSuggestions.add(s);
        }
      }

      emit(state.copyWith(
        status: SearchStatus.success,
        results: sortedResults,
        suggestions: mergedSuggestions.take(10).toList(),
        clearError: true,
      ));
    } catch (e) {
      if (state.query != query || isClosed) return;
      DLog.error('Lỗi tìm kiếm POI: $e');
      emit(state.copyWith(
        status: SearchStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Thực hiện tìm kiếm chính thức khi người dùng Submit / bấm vào từ khóa gợi ý
  Future<void> search(String query) async {
    _debounceTimer?.cancel();

    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty ||
        !Validator.instance.isValidSearchQuery(cleanQuery)) {
      emit(state.copyWith(
        status: SearchStatus.initial,
        query: cleanQuery,
        results: const [],
        clearError: true,
      ));
      return;
    }

    emit(state.copyWith(
      status: SearchStatus.loading,
      query: cleanQuery,
    ));

    try {
      final results = await _searchInCurrentArea(cleanQuery);

      if (state.query != cleanQuery || isClosed) return;

      // Sắp xếp kết quả tìm kiếm theo khoảng cách gần nhất
      final sortedResults =
          PoiCategoryHelper.sortPoisByDistance(results, state.userLocation);

      // Tự động lưu vào Recent Searches
      await _recentSearchService.addRecentSearch(cleanQuery);
      final updatedRecents = await _recentSearchService.getRecentSearches();

      if (state.query != cleanQuery || isClosed) return;

      emit(state.copyWith(
        status: SearchStatus.success,
        results: sortedResults,
        recentSearches: updatedRecents,
        clearError: true,
      ));
    } catch (e) {
      if (state.query != cleanQuery || isClosed) return;
      DLog.error('Lỗi thực hiện tìm kiếm: $e');
      emit(state.copyWith(
        status: SearchStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Tìm trong khu vực quanh tâm tìm kiếm.
  ///
  /// `userLocation` ở SearchState thực tế là tâm ưu tiên: GPS nếu có, hoặc
  /// tâm camera bản đồ do Home truyền vào. Khi không có tâm (ví dụ mở Search
  /// độc lập), giữ hành vi tìm toàn bộ database để không làm mất chức năng
  /// tìm kiếm hiện có.
  Future<List<PoiModel>> _searchInCurrentArea(String query) async {
    final center = state.userLocation;
    if (center == null) {
      return _poiRepository.search(query, limit: 50);
    }

    final cosLatitude = math.cos(center.latitude * math.pi / 180).abs();
    final safeCosLatitude = math.max(cosLatitude, 0.1).toDouble();

    for (final radiusKm in nearbySearchRadiusStepsKm) {
      final latDelta = radiusKm / 111.0;
      final lonDelta = radiusKm / (111.0 * safeCosLatitude);
      final results = await _poiRepository.searchInBounds(
        minLat: math.max(-90.0, center.latitude - latDelta).toDouble(),
        maxLat: math.min(90.0, center.latitude + latDelta).toDouble(),
        minLon: math.max(-180.0, center.longitude - lonDelta).toDouble(),
        maxLon: math.min(180.0, center.longitude + lonDelta).toDouble(),
        query: query,
        limit: 50,
      );

      // Dừng ở phạm vi nhỏ nhất có dữ liệu để giữ kết quả thật sự gần.
      if (results.isNotEmpty) return results;
    }

    // Bảo đảm vẫn tìm được dữ liệu ngoài vùng phủ của mốc 2.500 km,
    // chẳng hạn khi dataset sau này mở rộng sang quốc gia khác.
    return _poiRepository.search(query, limit: 50);
  }

  /// Nạp danh sách lịch sử tìm kiếm gần đây từ local storage
  Future<void> loadRecentSearches() async {
    try {
      final recents = await _recentSearchService.getRecentSearches();
      emit(state.copyWith(recentSearches: recents));
    } catch (e) {
      DLog.error('Lỗi nạp recent searches: $e');
    }
  }

  /// Thêm thủ công một từ khóa vào Recent Searches
  Future<void> addRecentSearch(String query) async {
    try {
      await _recentSearchService.addRecentSearch(query);
      await loadRecentSearches();
    } catch (e) {
      DLog.error('Lỗi thêm recent search: $e');
    }
  }

  /// Xóa một từ khóa khỏi Recent Searches
  Future<void> removeRecentSearch(String query) async {
    try {
      await _recentSearchService.removeRecentSearch(query);
      await loadRecentSearches();
    } catch (e) {
      DLog.error('Lỗi xóa recent search: $e');
    }
  }

  /// Xóa toàn bộ Recent Searches
  Future<void> clearRecentSearches() async {
    try {
      await _recentSearchService.clearRecentSearches();
      emit(state.copyWith(recentSearches: const []));
    } catch (e) {
      DLog.error('Lỗi dọn sạch recent searches: $e');
    }
  }

  /// Reset trạng thái tìm kiếm về mặc định
  void clearSearch() {
    _debounceTimer?.cancel();
    emit(state.copyWith(
      status: SearchStatus.initial,
      query: '',
      results: const [],
      suggestions: const [],
      clearError: true,
    ));
  }

  @override
  Future<void> close() async {
    _debounceTimer?.cancel();
    return super.close();
  }
}
