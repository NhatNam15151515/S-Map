import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/models/models.dart';
import 'search_current_location_tile.dart';
import 'search_input_field.dart';
import 'search_recent_list.dart';
import 'search_results_list.dart';

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

  const SearchScreenContent({
    super.key,
    this.hasExistingDestinations = false,
    this.onAcquireLocation,
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
    _textController = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleAcquireLocation() async {
    if (_isAcquiringLocation || widget.onAcquireLocation == null) return;
    setState(() => _isAcquiringLocation = true);
    try {
      final latLng = await widget.onAcquireLocation!();
      if (!mounted) return;
      if (latLng != null) {
        HapticFeedback.lightImpact();
        context.read<SearchCubit>().updateUserLocation(latLng);
      }
    } finally {
      if (mounted) setState(() => _isAcquiringLocation = false);
    }
  }

  Future<void> _handleSelectCurrentLocation(SearchState state) async {
    if (state.userLocation != null) {
      context.pop(SearchResultPayload.currentLocation(state.userLocation!));
      return;
    }
    await _handleAcquireLocation();
    if (!mounted) return;
    final loc = context.read<SearchCubit>().state.userLocation;
    if (loc != null) {
      context.pop(SearchResultPayload.currentLocation(loc));
    }
  }

  void _onPoiSelected(PoiModel poi) {
    context.read<SearchCubit>().addRecentSearch(poi.name);
    if (widget.hasExistingDestinations) {
      context.pop(SearchResultPayload.addDestination(poi));
    } else {
      context.pop(SearchResultPayload.single(poi));
    }
  }

  void _onAddDestination(PoiModel poi) {
    context.read<SearchCubit>().addRecentSearch(poi.name);
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
    context.read<SearchCubit>().search(text);
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

    final searchCubit = context.read<SearchCubit>();
    await searchCubit.search(clean);
    if (!mounted || searchCubit.state.query != clean) return;

    // Enter dùng cùng một danh sách kết quả với realtime search. Home map sẽ
    // hiển thị bottom sheet; nếu đang có route, mỗi item tự có nút thêm điểm.
    context.pop(
      SearchResultPayload.all(
        allResults: searchCubit.state.results,
        submittedQuery: clean,
      ),
    );
  }

  void _submitAreaSearch({String? query, String? category}) {
    final cleanQuery = query?.trim();
    final cleanCategory = category?.trim();
    if ((cleanQuery == null || cleanQuery.isEmpty) &&
        (cleanCategory == null || cleanCategory.isEmpty)) {
      return;
    }

    if (cleanQuery != null && cleanQuery.isNotEmpty) {
      context.read<SearchCubit>().addRecentSearch(cleanQuery);
    }

    context.pop(
      SearchResultPayload.areaSearch(
        submittedQuery: cleanQuery?.isNotEmpty == true ? cleanQuery : null,
        searchCategory:
            cleanCategory?.isNotEmpty == true ? cleanCategory : null,
        searchCenter: context.read<SearchCubit>().state.userLocation,
      ),
    );
  }

  void _onClear() {
    _textController.clear();
    context.read<SearchCubit>().clearSearch();
  }

  @override
  Widget build(BuildContext context) {
    final searchCubit = context.read<SearchCubit>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SearchInputField(
              controller: _textController,
              focusNode: _focusNode,
              onQueryChanged: searchCubit.onQueryChanged,
              onSubmitted: _onSubmitted,
              onClear: _onClear,
              onBackPressed: () => context.pop(),
            ),
            Expanded(
              child: BlocBuilder<SearchCubit, SearchState>(
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
                          onTap: () => _handleSelectCurrentLocation(state),
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
                            onItemRemove: searchCubit.removeRecentSearch,
                            onClearAll: searchCubit.clearRecentSearches,
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
