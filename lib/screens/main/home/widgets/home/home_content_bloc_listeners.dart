import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/main/home/widgets/home/home_search_coordinator.dart';

/// Gom nhóm toàn bộ MultiBlocListener của HomeScreenContent
class HomeContentBlocListeners extends StatelessWidget {
  final Widget child;
  final ValueChanged<PoiModel?> onSelectedPoiChanged;
  final ValueChanged<bool> onThemeChanged;
  final void Function(NavigationState prev, NavigationState curr)
      onNavigationChanged;
  final HomeSearchCoordinator searchCoordinator;
  final ValueChanged<PoiModel> onSinglePoiFound;

  const HomeContentBlocListeners({
    super.key,
    required this.child,
    required this.onSelectedPoiChanged,
    required this.onThemeChanged,
    required this.onNavigationChanged,
    required this.searchCoordinator,
    required this.onSinglePoiFound,
  });

  @override
  Widget build(BuildContext context) {
    NavigationState prevNavState = const NavigationState();

    return MultiBlocListener(
      listeners: [
        BlocListener<MapDisplayCubit, MapDisplayState>(
          listenWhen: (previous, current) =>
              previous.selectedPoi != current.selectedPoi,
          listener: (context, state) => onSelectedPoiChanged(state.selectedPoi),
        ),
        BlocListener<AppCubit, AppState>(
          listenWhen: (prev, curr) =>
              prev.themeMode != curr.themeMode || prev.appStyle != curr.appStyle,
          listener: (context, appState) => onThemeChanged(appState.isDarkMode),
        ),
        BlocListener<NavigationBloc, NavigationState>(
          listenWhen: (prev, curr) =>
              prev.status != curr.status ||
              prev.tripSummary != curr.tripSummary ||
              prev.promptBatteryOptimizationOem !=
                  curr.promptBatteryOptimizationOem ||
              prev.pendingResumeSession != curr.pendingResumeSession ||
              prev.errorMessageKey != curr.errorMessageKey,
          listener: (context, navState) {
            final prev = prevNavState;
            onNavigationChanged(prev, navState);
            prevNavState = navState;
          },
        ),
        BlocListener<ViewportSearchBloc, ViewportSearchState>(
          listenWhen: (prev, curr) =>
              prev.status != curr.status ||
              prev.pois != curr.pois ||
              prev.selectedCategory != curr.selectedCategory,
          listener: (context, viewportState) {
            final isAreaSearch = viewportState.isAreaSearch;
            final isCategorySearch =
                viewportState.selectedCategory != CategoryConstants.all;
            if (isAreaSearch || isCategorySearch) {
              final title = isCategorySearch
                  ? tr(PoiCategoryHelper.getCategoryLocaleKey(
                      viewportState.selectedCategory))
                  : viewportState.searchQuery;
              if (viewportState.status == ViewportSearchStatus.success) {
                final singlePoi = searchCoordinator.handleSearchResults(
                  viewportState.pois,
                  title,
                );
                if (singlePoi != null) onSinglePoiFound(singlePoi);
              } else if (viewportState.status == ViewportSearchStatus.empty) {
                searchCoordinator.handleSearchResults(const [], title);
              }
            }
          },
        ),
      ],
      child: child,
    );
  }
}
