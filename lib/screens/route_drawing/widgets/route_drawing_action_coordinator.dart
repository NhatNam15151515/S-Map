import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/routers/app_routes.dart';
import 'package:s_map/screens/route_drawing/widgets/save_custom_route_dialog.dart';
import 'package:s_map/screens/route_drawing/widgets/saved_routes_sheet.dart';

/// Điều phối các tác vụ modal và chuyển hướng navigation cho [RouteDrawingScreen].
/// 
/// Tách rời logic lưu tuyến đường, xem danh sách đã lưu và bắt đầu điều hướng.
class RouteDrawingActionCoordinator {
  const RouteDrawingActionCoordinator._();

  /// Mở dialog lưu tuyến đường tuỳ chỉnh vừa vẽ.
  static void showSaveRouteDialog({
    required BuildContext context,
    required RouteDrawingBloc drawingBloc,
  }) {
    final now = DateTime.now();
    final defaultName = tr(
      LocaleKeys.route_drawing_ui_default_route_name,
      args: [DateFormat('dd/MM/yyyy HH:mm').format(now)],
    );

    SaveCustomRouteDialog.show(
      context,
      initialName: defaultName,
      onSave: (name, description) {
        drawingBloc.add(
          RouteDrawingSaveRoute(
            name: name,
            description: description,
          ),
        );
      },
    );
  }

  /// Mở bottom sheet hiển thị danh sách các lộ trình đã lưu.
  static void showSavedRoutesSheet({
    required BuildContext context,
    required RouteDrawingBloc drawingBloc,
    required SavedRoutesCubit savedRoutesCubit,
  }) {
    SavedRoutesSheet.show(
      context,
      onRouteSelected: (route) {
        drawingBloc.add(RouteDrawingLoadRoute(route));
      },
      onRouteDeleted: (id) {
        savedRoutesCubit.deleteRoute(id);
      },
    );
  }

  /// Khởi tạo dữ liệu dẫn đường từ tuyến đường tự vẽ và chuyển sang chế độ Navigation trên Home.
  static void startNavigationFromDrawnRoute({
    required BuildContext context,
    required RouteDrawingState state,
  }) {
    if (!state.hasRoute) return;

    final rawPoints = state.fullPolyline.map((p) => [p.lat, p.lon]).toList();
    final customName = tr(LocaleKeys.route_drawing_ui_custom_route_name);
    final followInstruction =
        tr(LocaleKeys.route_drawing_ui_follow_custom_route);
    final instructions = <RouteInstruction>[
      RouteInstruction(
        text: followInstruction,
        streetName: customName,
        distance: state.totalDistance,
        time: state.totalTime,
        sign: 0,
        points: rawPoints,
      ),
    ];

    final customRoute = RouteResult(
      isSuccess: true,
      distance: state.totalDistance,
      time: state.totalTime,
      points: rawPoints,
      instructions: instructions,
    );

    try {
      context.read<NavigationBloc>().add(
            StartNavigation(
              initialRoute: customRoute,
              origin: state.fullPolyline.first,
              destination: state.fullPolyline.last,
              destinationName: customName,
            ),
          );
    } catch (_) {}

    context.go(AppRoutes.home);
  }
}
