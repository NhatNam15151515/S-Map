import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/transformers/transformers.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/commons/validators/validator.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/repos/repos.dart';
import 'package:s_map/search_engine/search_engine.dart';
import '../../fallbacks/search_fallbacks.dart';
import 'search_event.dart';
import 'search_state.dart';

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final IPoiRepository _poiRepository;
  final IRecentSearchService _recentSearchService;
  final SearchOrchestrator? _searchOrchestrator;

  List<String> _frequentSearches = const [];
  int _requestGeneration = 0;
  static const Duration defaultDebounceDuration = Duration(milliseconds: 160);

  /// Optional global default service resolver set by the app shell
  static IRecentSearchService? defaultRecentSearchService;

  SearchBloc({
    IPoiRepository? poiRepository,
    IRecentSearchService? recentSearchService,
    LatLng? userLocation,
    SearchOrchestrator? searchOrchestrator,
  }) : _poiRepository = poiRepository ?? PoiRepositoryImpl(),
       _recentSearchService =
           recentSearchService ??
           defaultRecentSearchService ??
           NoOpRecentSearchService(),
       _searchOrchestrator = searchOrchestrator,
       super(SearchState(userLocation: userLocation)) {
    on<SearchQueryChanged>(_onQueryChanged, transformer: restartable());
    on<SearchSubmitted>(_onSearchSubmitted, transformer: restartable());
    on<SearchUserLocationChanged>(_onUserLocationChanged);
    on<SearchCleared>(_onSearchCleared);
    on<SearchHistoryEvent>(_onHistoryEvent, transformer: sequential());
  }

  /// Cập nhật vị trí GPS người dùng để tính khoảng cách tới các POI
  void _onUserLocationChanged(
    SearchUserLocationChanged event,
    Emitter<SearchState> emit,
  ) {
    final sortedResults = SearchResultRanker.rank(
      state.results,
      center: event.location,
      query: state.query,
      limit: state.results.length,
    );
    emit(state.copyWith(userLocation: event.location, results: sortedResults));
  }

  Future<void> _onQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) async {
    final generation = ++_requestGeneration;
    final cleanQuery = event.query.trim();
    if (cleanQuery.isEmpty) {
      emit(
        state.copyWith(
          status: SearchStatus.initial,
          query: '',
          results: const [],
          suggestions: const [],
          submitCompleted: false,
          clearError: true,
        ),
      );
      return;
    }

    // Publish the query before debounce so old requests cannot win the race.
    emit(state.copyWith(query: cleanQuery, submitCompleted: false));
    await Future<void>.delayed(
      event.debounceDuration ?? defaultDebounceDuration,
    );
    if (emit.isDone || generation != _requestGeneration) return;
    await _fetchSuggestionsAndResults(cleanQuery, emit, generation);
  }

  /// Tải song song cả danh sách Gợi ý (Suggestions) và Kết quả tìm kiếm (Results)
  Future<void> _fetchSuggestionsAndResults(
    String query,
    Emitter<SearchState> emit,
    int generation,
  ) async {
    if (emit.isDone || generation != _requestGeneration) return;
    if (!Validator.instance.isValidSearchQuery(query)) {
      emit(
        state.copyWith(
          status: SearchStatus.initial,
          query: query,
          results: const [],
          suggestions: const [],
          submitCompleted: false,
          clearError: true,
        ),
      );
      return;
    }

    emit(state.copyWith(status: SearchStatus.loading, query: query));

    final searchTimer = Stopwatch()..start();
    DLog.searchTrace(
      '[SearchAutocomplete] start query="$query" '
      'hasLocation=${state.userLocation != null}',
    );

    try {
      // Autocomplete uses the shared parser plus local R*Tree and trie prefixes.
      final results =
          await (_searchOrchestrator?.searchAutocomplete(
                query: query,
                userLocation: state.userLocation,
                limit: 20,
              ) ??
              _poiRepository.search(query, limit: 20));
      DLog.searchTrace(
        '[SearchAutocomplete] results=${results.length} '
        'elapsed=${searchTimer.elapsedMilliseconds}ms',
      );

      // Khi có POI, UI ưu tiên render danh sách POI và không dùng keyword
      // suggestions. Tránh chạy thêm một truy vấn FTS ở mỗi phím gõ.
      final dbSuggestions = results.isEmpty
          ? await _poiRepository.getSuggestions(query, limit: 10)
          : const <String>[];

      // Đảm bảo kết quả phản hồi khớp với query hiện tại, tránh race condition
      if (state.query != query ||
          emit.isDone ||
          generation != _requestGeneration) {
        return;
      }

      // Dùng cùng bộ xếp hạng với area search và Route Drawing.
      final sortedResults = SearchResultRanker.rank(
        results,
        center: state.userLocation,
        query: query,
        limit: 20,
      );

      // Lọc từ khóa thường tìm và gần đây theo cùng quy tắc dấu tiếng Việt.
      final matchedFrequent = _matchingSearches(_frequentSearches, query);
      final matchedRecents = _matchingSearches(state.recentSearches, query);

      // Ưu tiên từ khóa thường tìm, sau đó lịch sử và gợi ý POI.
      final mergedSuggestions = <String>[];
      final seen = <String>{};

      for (final s in [...matchedFrequent, ...matchedRecents]) {
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

      emit(
        state.copyWith(
          status: SearchStatus.success,
          results: sortedResults,
          suggestions: mergedSuggestions.take(10).toList(),
          clearError: true,
        ),
      );
      DLog.searchTrace(
        '[SearchAutocomplete] emitted=${sortedResults.length} '
        'suggestions=${mergedSuggestions.length} '
        'total=${searchTimer.elapsedMilliseconds}ms',
      );
    } catch (e) {
      if (state.query != query ||
          emit.isDone ||
          generation != _requestGeneration) {
        return;
      }
      DLog.error(
        '[SearchAutocomplete] failed after '
        '${searchTimer.elapsedMilliseconds}ms: $e',
      );
      emit(
        state.copyWith(status: SearchStatus.error, errorMessage: e.toString()),
      );
    }
  }

  /// Thực hiện tìm kiếm chính thức khi người dùng Submit / bấm vào từ khóa gợi ý
  Future<void> _onSearchSubmitted(
    SearchSubmitted event,
    Emitter<SearchState> emit,
  ) async {
    final generation = ++_requestGeneration;
    final cleanQuery = event.query.trim();
    if (cleanQuery.isEmpty ||
        !Validator.instance.isValidSearchQuery(cleanQuery)) {
      emit(
        state.copyWith(
          status: SearchStatus.initial,
          query: cleanQuery,
          results: const [],
          suggestions: const [],
          submitCompleted: false,
          clearError: true,
        ),
      );
      _complete(event.completer);
      return;
    }

    emit(
      state.copyWith(
        status: SearchStatus.loading,
        query: cleanQuery,
        submitCompleted: false,
      ),
    );

    try {
      final results = await _searchInCurrentArea(
        cleanQuery,
        state.userLocation,
      );

      if (state.query != cleanQuery ||
          emit.isDone ||
          generation != _requestGeneration) {
        return;
      }

      // Submit search cũng phải dùng cùng ranking với realtime search và
      // Route Drawing, không quay lại cách chỉ sắp theo khoảng cách.
      final sortedResults = SearchResultRanker.rank(
        results,
        center: state.userLocation,
        query: cleanQuery,
        limit: 50,
      );

      // Tự động lưu vào Recent Searches
      await _recentSearchService.addRecentSearch(cleanQuery);
      final updatedSearchData = await Future.wait([
        _recentSearchService.getRecentSearches(),
        _recentSearchService.getFrequentSearches(),
      ]);

      if (state.query != cleanQuery ||
          emit.isDone ||
          generation != _requestGeneration) {
        return;
      }
      _frequentSearches = updatedSearchData[1];

      emit(
        state.copyWith(
          status: SearchStatus.success,
          results: sortedResults,
          recentSearches: updatedSearchData[0],
          submitCompleted: event.returnResults,
          clearError: true,
        ),
      );
    } catch (e) {
      if (state.query != cleanQuery ||
          emit.isDone ||
          generation != _requestGeneration) {
        return;
      }
      DLog.error('Lỗi thực hiện tìm kiếm: $e');
      emit(
        state.copyWith(
          status: SearchStatus.error,
          submitCompleted: false,
          errorMessage: e.toString(),
        ),
      );
    } finally {
      _complete(event.completer);
    }
  }

  /// Tìm ứng viên text qua search engine hiện tại.
  Future<List<PoiModel>> _searchInCurrentArea(
    String query,
    LatLng? userLocation,
  ) async {
    return _searchOrchestrator?.search(
          query: query,
          userLocation: userLocation,
          limit: 50,
        ) ??
        _poiRepository.search(query, limit: 50);
  }

  Future<void> _onHistoryEvent(
    SearchHistoryEvent event,
    Emitter<SearchState> emit,
  ) async {
    try {
      if (event is SearchHistoryLoadRequested) {
        await _loadRecentSearches(emit);
      } else if (event is SearchRecentAdded) {
        await _recentSearchService.addRecentSearch(event.query);
        await _loadRecentSearches(emit);
      } else if (event is SearchDestinationAdded) {
        await _recentSearchService.addRecentSearch(
          event.poi.name,
          destination: event.poi.toMap(),
        );
        await _loadRecentSearches(emit);
      } else if (event is SearchRecentRemoved) {
        await _recentSearchService.removeRecentSearch(event.query);
        await _loadRecentSearches(emit);
      } else if (event is SearchHistoryCleared) {
        await _recentSearchService.clearRecentSearches();
        _frequentSearches = const [];
        emit(state.copyWith(recentSearches: const []));
      }
    } catch (error) {
      DLog.error('Search history event failed: $error');
    } finally {
      _complete(event.completer);
    }
  }

  Future<void> _loadRecentSearches(Emitter<SearchState> emit) async {
    final results = await Future.wait([
      _recentSearchService.getRecentSearches(),
      _recentSearchService.getFrequentSearches(),
    ]);
    if (emit.isDone) return;
    _frequentSearches = results[1];
    emit(state.copyWith(recentSearches: results[0]));
  }

  List<String> _matchingSearches(Iterable<String> searches, String query) {
    final hasDiacritics = Validator.instance.hasDiacritics(query);
    final lowerQuery = query.toLowerCase();
    final asciiQuery = AppUtils.instance.toAscii(query).toLowerCase();
    return searches.where((value) {
      final lowerValue = value.toLowerCase();
      if (hasDiacritics) return lowerValue.contains(lowerQuery);
      final asciiValue = AppUtils.instance.toAscii(value).toLowerCase();
      return lowerValue.contains(lowerQuery) || asciiValue.contains(asciiQuery);
    }).toList();
  }

  void _onSearchCleared(SearchCleared event, Emitter<SearchState> emit) {
    _requestGeneration++;
    emit(
      state.copyWith(
        status: SearchStatus.initial,
        query: '',
        results: const [],
        suggestions: const [],
        submitCompleted: false,
        clearError: true,
      ),
    );
  }

  void _complete(Completer<void>? completer) {
    if (completer != null && !completer.isCompleted) completer.complete();
  }
}
