import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/models/models.dart';
import 'search_current_location_tile.dart';
import 'search_input_field.dart';
import 'search_recent_list.dart';
import 'search_results_list.dart';
import 'voice_search_bottom_sheet.dart';

/// Nội dung chính của màn hình tìm kiếm.
///
/// Trách nhiệm:
/// - Điều phối luồng nhập từ khóa và hiển thị kết quả / lịch sử tìm kiếm.
/// - Nhận trạng thái [hasExistingDestinations] thuần túy từ caller, không phụ thuộc
///   vào các Cubit ngoại vi khác như RoutePreviewCubit.
/// - Không gọi trực tiếp Singleton Service; ủy thác việc lấy tọa độ qua [onAcquireLocation].
class SearchScreenContent extends StatefulWidget {
  final bool hasExistingDestinations;
  final Future<LatLng?> Function()? onAcquireLocation;
  final String? initialQuery;

  const SearchScreenContent({
    super.key,
    this.hasExistingDestinations = false,
    this.onAcquireLocation,
    this.initialQuery,
  });

  @override
  State<SearchScreenContent> createState() => _SearchScreenContentState();
}

class _SearchScreenContentState extends State<SearchScreenContent> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  bool _isAcquiringLocation = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialQuery ?? '');
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<LatLng?> _acquireFreshLocation() async {
    if (_isAcquiringLocation || widget.onAcquireLocation == null) return null;
    setState(() => _isAcquiringLocation = true);
    try {
      final latLng = await widget.onAcquireLocation!();
      if (mounted && latLng != null) {
        HapticFeedback.lightImpact();
        context.read<SearchBloc>().add(SearchUserLocationChanged(latLng));
      }
      return latLng;
    } finally {
      if (mounted) setState(() => _isAcquiringLocation = false);
    }
  }

  Future<void> _handleSelectCurrentLocation() async {
    // The incoming position may be the map center or a stale cached fix.
    // Selecting current location must resolve a fresh GPS fix.
    final loc = await _acquireFreshLocation();
    if (!mounted) return;
    if (loc != null) {
      context.pop(SearchResultPayload.currentLocation(loc));
    }
  }

  void _onPoiSelected(PoiModel poi) {
    context.read<SearchBloc>().add(SearchDestinationAdded(poi));
    if (widget.hasExistingDestinations) {
      context.pop(SearchResultPayload.addDestination(poi));
    } else {
      context.pop(SearchResultPayload.single(poi));
    }
  }

  void _onAddDestination(PoiModel poi) {
    context.read<SearchBloc>().add(SearchDestinationAdded(poi));
    context.pop(SearchResultPayload.addDestination(poi));
  }

  void _onCategorySelected(String category) {
    if (widget.hasExistingDestinations) {
      _applySearchQuery(category);
    } else {
      _updateTextAndSubmit(category, isCategory: true);
    }
  }

  void _onKeywordSelected(String keyword) {
    if (widget.hasExistingDestinations) {
      _applySearchQuery(keyword);
    } else {
      _updateTextAndSubmit(keyword, isCategory: false);
    }
  }

  void _applySearchQuery(String text) {
    _textController.text = text;
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
    _focusNode.unfocus();
    context.read<SearchBloc>().add(SearchSubmitted(text));
  }

  void _updateTextAndSubmit(String value, {required bool isCategory}) {
    _textController.text = value;
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: value.length),
    );
    if (isCategory) {
      _submitAreaSearch(category: value);
    } else {
      _submitAreaSearch(query: value);
    }
  }

  Future<void> _onSubmitted(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;
    context
        .read<SearchBloc>()
        .add(SearchSubmitted(clean, returnResults: true));
  }

  void _submitAreaSearch({String? query, String? category}) {
    final cleanQuery = query?.trim();
    final cleanCategory = category?.trim();
    if ((cleanQuery == null || cleanQuery.isEmpty) &&
        (cleanCategory == null || cleanCategory.isEmpty)) {
      return;
    }

    if (cleanQuery != null && cleanQuery.isNotEmpty) {
      context.read<SearchBloc>().add(SearchRecentAdded(cleanQuery));
    }

    context.pop(
      SearchResultPayload.areaSearch(
        submittedQuery: cleanQuery?.isNotEmpty == true ? cleanQuery : null,
        searchCategory:
            cleanCategory?.isNotEmpty == true ? cleanCategory : null,
        searchCenter: context.read<SearchBloc>().state.userLocation,
      ),
    );
  }

  void _onClear() {
    _textController.clear();
    context.read<SearchBloc>().add(const SearchCleared());
  }

  @override
  Widget build(BuildContext context) {
    final searchBloc = context.read<SearchBloc>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SearchInputField(
              controller: _textController,
              focusNode: _focusNode,
              onQueryChanged: (query) =>
                  searchBloc.add(SearchQueryChanged(query)),
              onSubmitted: _onSubmitted,
              onClear: _onClear,
              onBackPressed: () => context.pop(),
              onVoicePressed: () async {
                final query = await showVoiceSearchBottomSheet(context);
                if (query != null && query.isNotEmpty && mounted) {
                  _textController.text = query;
                  _textController.selection = TextSelection.fromPosition(
                    TextPosition(offset: query.length),
                  );
                  setState(() {});
                  searchBloc.add(SearchQueryChanged(query));
                }
              },
            ),
            Expanded(
              child: BlocConsumer<SearchBloc, SearchState>(
                listenWhen: (previous, current) =>
                    !previous.submitCompleted && current.submitCompleted,
                listener: (context, state) {
                  // Enter returns the current full result list to the map.
                  context.pop(
                    SearchResultPayload.all(
                      allResults: state.results,
                      submittedQuery: state.query,
                    ),
                  );
                },
                builder: (context, state) {
                  final isQueryEmpty =
                      state.query.isEmpty && state.results.isEmpty;

                  if (isQueryEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SearchCurrentLocationTile(
                          userLocation: state.userLocation,
                          isAcquiringLocation: _isAcquiringLocation,
                          onTap: _handleSelectCurrentLocation,
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        const SizedBox(height: 4),
                        MapCategoryChips(
                          onCategorySelected: _onCategorySelected,
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SearchRecentList(
                            recentSearches: state.recentSearches,
                            onItemTap: _onKeywordSelected,
                            onItemRemove: (query) => searchBloc
                                .add(SearchRecentRemoved(query)),
                            onClearAll: () => searchBloc
                                .add(const SearchHistoryCleared()),
                          ),
                        ),
                      ],
                    );
                  }

                  return SearchResultsList(
                    results: state.results,
                    suggestions: state.suggestions,
                    isLoading: state.status == SearchStatus.loading,
                    userLocation: state.userLocation,
                    onPoiTap: _onPoiSelected,
                    onSuggestionTap: _onKeywordSelected,
                    hasExistingDestinations: widget.hasExistingDestinations,
                    onAddDestination: _onAddDestination,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
