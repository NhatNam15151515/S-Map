import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/models/models.dart';
import 'search_input_field.dart';
import 'search_recent_list.dart';
import 'search_results_list.dart';

class SearchScreenContent extends StatefulWidget {
  const SearchScreenContent({super.key});

  @override
  State<SearchScreenContent> createState() => _SearchScreenContentState();
}

class _SearchScreenContentState extends State<SearchScreenContent>
    with AppMixin {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;

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

  void _onPoiSelected(PoiModel poi) {
    final cubit = context.read<SearchCubit>();
    cubit.addRecentSearch(poi.name);
    context.pop(SearchResultPayload.single(poi));
  }

  void _onCategorySelected(String category) {
    _textController.text = category;
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: category.length),
    );
    _submitAreaSearch(category: category);
  }

  void _onKeywordSelected(String keyword) {
    _textController.text = keyword;
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: keyword.length),
    );
    _submitAreaSearch(query: keyword);
  }

  void _onSubmitted(String query) {
    final clean = query.trim();
    if (clean.isEmpty) return;
    _submitAreaSearch(query: clean);
  }

  /// Submit chỉ trả intent về Home. Home dùng cùng một progressive engine với
  /// category chip; kết quả realtime trên SearchScreen chỉ có vai trò gợi ý.
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
            // 1. Search Input Bar
            SearchInputField(
              controller: _textController,
              focusNode: _focusNode,
              onQueryChanged: (query) {
                searchCubit.onQueryChanged(query);
              },
              onSubmitted: _onSubmitted,
              onClear: _onClear,
              onBackPressed: () => context.pop(),
            ),

            // 2. Main Content: Recent/Category or Search Results
            Expanded(
              child: BlocBuilder<SearchCubit, SearchState>(
                builder: (context, state) {
                  final isQueryEmpty =
                      state.query.isEmpty && state.results.isEmpty;

                  if (isQueryEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        MapCategoryChips(
                          onCategorySelected: _onCategorySelected,
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SearchRecentList(
                            recentSearches: state.recentSearches,
                            onItemTap: _onKeywordSelected,
                            onItemRemove: (q) =>
                                searchCubit.removeRecentSearch(q),
                            onClearAll: () => searchCubit.clearRecentSearches(),
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
