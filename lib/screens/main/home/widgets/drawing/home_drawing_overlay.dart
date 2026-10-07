import 'package:flutter/material.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/main/home/widgets/drawing/widgets.dart';
import 'package:s_map/screens/main/home/widgets/home/home_route_actions.dart';
import 'package:s_map/screens/main/home/widgets/home/home_poi_quick_card.dart';
import 'package:s_map/screens/main/home/widgets/home/home_search_results_sheet.dart';

/// Overlay chế độ vẽ lộ trình tuỳ chỉnh (Route Drawing State).
///
/// Quản lý đồng bộ:
/// - Top: Waypoint Panel (danh sách điểm dừng, kéo thả sắp xếp, chim bay từng đoạn)
/// - Center: Crosshair Overlay (nút thêm điểm tại tâm bản đồ)
/// - Bottom: Route Drawing Bottom Card (thống kê km/thời gian, lưu/bắt đầu lộ trình)
///   hoặc PoiQuickCard / SearchResultsBottomSheet khi người dùng tương tác tìm kiếm địa điểm trên bản đồ.
class HomeDrawingOverlay extends StatelessWidget {
  final double topPadding;
  final RouteDrawingState drawingState;
  final RouteDrawingBloc drawingBloc;
  final SavedRoutesCubit savedRoutesCubit;
  final bool isCrosshairActive;
  final bool isDrawingMode;
  final PoiModel? selectedMarkerPoi;
  final List<PoiModel>? searchResults;
  final String? searchQuery;
  final VoidCallback onAddPointAtCenter;
  final VoidCallback onOpenSearch;
  final VoidCallback onExit;
  final ValueChanged<PoiModel> onDrawingPoiTap;
  final ValueChanged<PoiModel> onAddDestination;
  final VoidCallback? onToggleDrawingMode;
  final VoidCallback onCloseSearchResults;
  final VoidCallback onClosePoiCard;
  final VoidCallback? onNavigatePressed;

  const HomeDrawingOverlay({
    super.key,
    required this.topPadding,
    required this.drawingState,
    required this.drawingBloc,
    required this.savedRoutesCubit,
    required this.isCrosshairActive,
    this.isDrawingMode = true,
    this.selectedMarkerPoi,
    this.searchResults,
    this.searchQuery,
    required this.onAddPointAtCenter,
    required this.onOpenSearch,
    required this.onExit,
    required this.onDrawingPoiTap,
    required this.onAddDestination,
    this.onToggleDrawingMode,
    required this.onCloseSearchResults,
    required this.onClosePoiCard,
    this.onNavigatePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Top Area: Waypoint Panel
        RouteDrawingWaypointPanel(
          topPadding: topPadding,
          points: drawingState.points,
          segments: drawingState.segments,
          onSavedRoutesPressed: () => HomeRouteActions.showSavedRoutesSheet(
            context: context,
            drawingBloc: drawingBloc,
            savedRoutesCubit: savedRoutesCubit,
          ),
          onSearchDestinationPressed: onOpenSearch,
          onReorder: (oldIndex, newIndex) => drawingBloc.add(
            RouteDrawingReorderPoints(oldIndex, newIndex),
          ),
          onRemovePoint: (index) => drawingBloc.add(
            RouteDrawingRemovePoint(index),
          ),
          onToggleSegmentStraightLine: (segmentIndex) => drawingBloc.add(
            RouteDrawingToggleSegmentStraightLine(segmentIndex),
          ),
          showStraightLineToggles: isDrawingMode,
        ),

        // 2. Center Area: Crosshair overlay
        if (isDrawingMode && isCrosshairActive)
          RouteDrawingCrosshairOverlay(
            isLoading: drawingState.isLoading,
            hasPoints: drawingState.points.isNotEmpty,
            onAddPoint: onAddPointAtCenter,
            bottomOffset: MediaQuery.paddingOf(context).bottom +
                (drawingState.points.length >= 2 ? 190 : 130),
          ),

        // 3. Bottom Area: Contextual Card
        _buildBottomContent(context),
      ],
    );
  }

  Widget _buildBottomContent(BuildContext context) {
    // 3a. Ưu tiên 1: Đang chọn 1 POI trên bản đồ -> hiển thị Quick Card kèm nút "Thêm vào lộ trình"
    if (selectedMarkerPoi != null) {
      return Positioned(
        left: 0,
        right: 0,
        bottom: kBottomNavigationBarHeight +
            MediaQuery.paddingOf(context).bottom +
            8,
        child: SafeArea(
          top: false,
          child: HomePoiQuickCard(
            poi: selectedMarkerPoi!,
            onClose: onClosePoiCard,
            onAddDestination: () => onAddDestination(selectedMarkerPoi!),
          ),
        ),
      );
    }

    // 3b. Ưu tiên 2: Đang có kết quả tìm kiếm inline -> hiển thị Bottom Sheet kết quả
    if (searchResults != null) {
      // MainScreen's persistent bottom bar is painted above the Home body.
      // Keep the draggable sheet above that hit-test area so taps in its lower
      // rows cannot activate tabs behind the sheet.
      return Padding(
        padding: EdgeInsets.only(
          bottom: kBottomNavigationBarHeight +
              MediaQuery.paddingOf(context).bottom +
              8,
        ),
        child: HomeSearchResultsSheet(
          key: const ValueKey('drawing_search_results_sheet'),
          pois: searchResults!,
          query: searchQuery,
          hasExistingDestinations: true,
          onPoiTap: onDrawingPoiTap,
          onAddDestination: onAddDestination,
          onClose: onCloseSearchResults,
        ),
      );
    }

    // 3c. Mặc định: Hiển thị Bottom Card tóm tắt lộ trình (km, thời gian, Lưu, Bắt đầu đi)
    return RouteDrawingBottomCard(
      pointCount: drawingState.pointCount,
      distanceMeters: drawingState.totalDistance,
      durationMs: drawingState.totalTime,
      isLoading: drawingState.isLoading,
      isStraightLineMode: drawingState.isStraightLineMode,
      isDrawingMode: isDrawingMode,
      onToggleDrawingMode: onToggleDrawingMode,
      onClose: onExit,
      onSavePressed: () => HomeRouteActions.showSaveRouteDialog(
        context: context,
        drawingBloc: drawingBloc,
      ),
      onNavigatePressed: onNavigatePressed ??
          () {
            HomeRouteActions.startNavigationFromDrawnRoute(
              context: context,
              state: drawingState,
            );
            onExit();
          },
    );
  }
}
