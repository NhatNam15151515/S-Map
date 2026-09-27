import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/main/home/widgets/widgets.dart';

/// Overlay chế độ xem trước lộ trình (RouteDirectionHeader + RoutePreviewBottomSheet)
class HomeRoutePreviewOverlay extends StatelessWidget {
  final double topPadding;
  final RoutePreviewState routeState;
  final HomeRouteActions routeActions;
  final VoidCallback onStartNavigationTriggered;
  final List<PoiModel>? searchResults;
  final String? searchQuery;
  final PoiModel? selectedSearchPoi;
  final ValueChanged<PoiModel>? onSearchResultPoiTap;
  final ValueChanged<PoiModel>? onAddDestination;
  final VoidCallback? onCloseSearchResults;
  final VoidCallback? onCloseSearchPoi;

  const HomeRoutePreviewOverlay({
    super.key,
    required this.topPadding,
    required this.routeState,
    required this.routeActions,
    required this.onStartNavigationTriggered,
    this.searchResults,
    this.searchQuery,
    this.selectedSearchPoi,
    this.onSearchResultPoiTap,
    this.onAddDestination,
    this.onCloseSearchResults,
    this.onCloseSearchPoi,
  });

  @override
  Widget build(BuildContext context) {
    final routePreviewCubit = context.read<RoutePreviewCubit>();
    final navigationBloc = context.read<NavigationBloc>();
    final isSearchList = searchResults != null && selectedSearchPoi == null;

    return Stack(
      children: [
        RouteDirectionHeader(
          topPadding: topPadding,
          onSelectOrigin: () => routeActions.handleSelectEndpointForRoute(
            context,
            isOrigin: true,
            mounted: true,
          ),
          onSelectDestination: () => routeActions.handleSelectEndpointForRoute(
            context,
            isOrigin: false,
            mounted: true,
          ),
          onAddDestination: () =>
              routeActions.handleOpenAddDestinationSearch(context),
          onClose: () {
            DLog.info('❌ [HomeScreen] Close Route Preview tapped');
            routePreviewCubit.clearRoute();
          },
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SizedBox(
            height: isSearchList
                ? MediaQuery.sizeOf(context).height * 0.72
                : null,
            child: SafeArea(
              top: false,
              child: _buildBottomContent(
                context,
                routePreviewCubit: routePreviewCubit,
                navigationBloc: navigationBloc,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomContent(
    BuildContext context, {
    required RoutePreviewCubit routePreviewCubit,
    required NavigationBloc navigationBloc,
  }) {
    if (searchResults != null) {
      if (selectedSearchPoi != null) {
        return PoiQuickCard(
          poi: selectedSearchPoi!,
          onClose: onCloseSearchPoi ?? () {},
          onAddDestination: onAddDestination == null
              ? null
              : () => onAddDestination!(selectedSearchPoi!),
        );
      }

      return SearchResultsBottomSheet(
        key: const ValueKey('route_search_results_bottom_sheet'),
        pois: searchResults!,
        query: searchQuery,
        hasExistingDestinations: true,
        onPoiTap: onSearchResultPoiTap,
        onAddDestination: onAddDestination,
        onClose: onCloseSearchResults,
      );
    }

    return RoutePreviewBottomSheet(
      onClose: () {
        DLog.info('❌ [HomeScreen] Close Route Preview tapped');
        routePreviewCubit.clearRoute();
      },
      onCustomRoute: routeState.destination != null
          ? () => routeActions.handleOpenCustomRouteDrawing(
                context,
                destination: LatLng(
                  routeState.destination!.lat,
                  routeState.destination!.lon,
                ),
                destinationName: routeState.destinationName,
              )
          : null,
      onStartNavigation: () {
        if (routeState.currentRoute != null &&
            routeState.origin != null &&
            routeState.destination != null) {
          DLog.info('🚀 [HomeScreen] Starting Turn-by-Turn Navigation');
          onStartNavigationTriggered();
          navigationBloc.add(StartNavigation(
            initialRoute: routeState.currentRoute!,
            origin: routeState.origin!,
            destination: routeState.destination!,
            destinationName: routeState.destinationName,
            profile: routeState.currentProfile,
          ));
        }
      },
    );
  }
}
