import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/services/services.dart';
import 'widgets/widgets.dart';

class SearchScreen extends StatefulWidget {
  static const String path = '/search';

  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with AppMixin {
  late final SearchCubit _searchCubit;

  @override
  void initState() {
    super.initState();
    _searchCubit = SearchCubit(
      recentSearchService: RecentSearchServiceImpl.instance,
    )..loadRecentSearches();
  }

  @override
  void dispose() {
    _searchCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _searchCubit,
      child: const _SearchScreenContent(),
    );
  }
}

class _SearchScreenContent extends StatefulWidget {
  const _SearchScreenContent();

  @override
  State<_SearchScreenContent> createState() => _SearchScreenContentState();
}

class _SearchScreenContentState extends State<_SearchScreenContent>
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
    context.pop(poi);
  }

  void _onCategorySelected(String category) {
    _textController.text = category;
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: category.length),
    );
    context.read<SearchCubit>().search(category);
  }

  void _onKeywordSelected(String keyword) {
    _textController.text = keyword;
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: keyword.length),
    );
    context.read<SearchCubit>().search(keyword);
  }

  void _onClear() {
    _textController.clear();
    context.read<SearchCubit>().clearSearch();
  }

  @override
  Widget build(BuildContext context) {
    final searchCubit = context.read<SearchCubit>();

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Search Input Bar
            SearchInputField(
              controller: _textController,
              focusNode: _focusNode,
              onQueryChanged: (query) => searchCubit.onQueryChanged(query),
              onSubmitted: (query) => searchCubit.search(query),
              onClear: _onClear,
              onBackPressed: () => context.pop(),
            ),

            // 2. Main Content: Recent/Category or Search Results
            Expanded(
              child: BlocBuilder<SearchCubit, SearchState>(
                builder: (context, state) {
                  final isQueryEmpty = state.query.isEmpty && state.results.isEmpty;

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
                            onItemRemove: (q) => searchCubit.removeRecentSearch(q),
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
