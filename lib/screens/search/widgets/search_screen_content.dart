import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/services/location_services.dart';
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
    if (_isAcquiringLocation) return;
    setState(() => _isAcquiringLocation = true);
    try {
      final pos = await LocationService.instance.getCurrentPosition();
      if (!mounted) return;
      HapticFeedback.lightImpact();
      final latLng = LatLng(pos.latitude, pos.longitude);
      context.read<SearchCubit>().updateUserLocation(latLng);
    } catch (e) {
      DLog.warning('⚠️ [SearchScreen] Could not acquire location: $e');
    } finally {
      if (mounted) setState(() => _isAcquiringLocation = false);
    }
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

  Widget _buildEnableLocationBanner(
      BuildContext context, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on_outlined,
            size: 18,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tr(LocaleKeys.map_location_service_disabled),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _handleAcquireLocation,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isAcquiringLocation
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    tr(LocaleKeys.map_current_location),
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentLocationTile(BuildContext context, SearchState state) {
    final colorScheme = context.colorScheme;
    final hasLocation = state.userLocation != null;

    return InkWell(
      onTap: () async {
        if (hasLocation) {
          context.pop(SearchResultPayload.currentLocation(state.userLocation!));
        } else {
          await _handleAcquireLocation();
          if (!context.mounted) return;
          final loc = context.read<SearchCubit>().state.userLocation;
          if (loc != null) {
            context.pop(SearchResultPayload.currentLocation(loc));
          }
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: _isAcquiringLocation
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(colorScheme.primary),
                      ),
                    )
                  : Icon(
                      Icons.my_location_rounded,
                      size: 20,
                      color: colorScheme.primary,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(LocaleKeys.routing_my_location),
                    style:
                        colorScheme.onSurface.textTheme.semiBoldStyle.copyWith(
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasLocation
                        ? tr(LocaleKeys.map_current_location)
                        : tr(LocaleKeys.map_location_service_disabled),
                    style: colorScheme.onSurfaceVariant.textTheme.textStyle
                        .copyWith(
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchCubit = context.read<SearchCubit>();
    final colorScheme = Theme.of(context).colorScheme;

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

            // 2. Main Content: Location banner, Recent/Category or Search Results
            Expanded(
              child: BlocBuilder<SearchCubit, SearchState>(
                builder: (context, state) {
                  final isQueryEmpty =
                      state.query.isEmpty && state.results.isEmpty;

                  return Column(
                    children: [
                      // Location banner if user has not enabled location yet
                      if (state.userLocation == null)
                        _buildEnableLocationBanner(context, colorScheme),

                      Expanded(
                        child: isQueryEmpty
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Google Maps quick option: "Vị trí hiện tại của bạn"
                                  _buildCurrentLocationTile(context, state),
                                  const Divider(
                                      height: 1, indent: 16, endIndent: 16),
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
                                      onClearAll: () =>
                                          searchCubit.clearRecentSearches(),
                                    ),
                                  ),
                                ],
                              )
                            : SearchResultsList(
                                results: state.results,
                                suggestions: state.suggestions,
                                isLoading: state.status == SearchStatus.loading,
                                userLocation: state.userLocation,
                                onPoiTap: _onPoiSelected,
                                onSuggestionTap: _onKeywordSelected,
                              ),
                      ),
                    ],
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
