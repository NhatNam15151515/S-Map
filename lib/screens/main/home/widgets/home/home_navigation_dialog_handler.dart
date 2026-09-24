import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/screens/main/home/widgets/home/home_dialog_coordinator.dart';

/// Điều phối hiển thị các hộp thoại liên quan đến trạng thái Navigation
class HomeNavigationDialogHandler {
  final BuildContext context;
  final RoutePreviewCubit routePreviewCubit;
  final NavigationBloc navigationBloc;
  final void Function(String) onError;
  bool isTripSummaryShown = false;

  HomeNavigationDialogHandler({
    required this.context,
    required this.routePreviewCubit,
    required this.navigationBloc,
    required this.onError,
  });

  void handleNavigationState(NavigationState prev, NavigationState curr) {
    if (!isTripSummaryShown &&
        prev.status != curr.status &&
        curr.tripSummary != null &&
        (curr.status == NavigationStatus.arrived ||
            curr.status == NavigationStatus.stopped)) {
      isTripSummaryShown = true;
      HomeDialogCoordinator.showTripSummaryModal(
        context: context,
        summary: curr.tripSummary!,
        onDone: () {
          routePreviewCubit.clearRoute();
          navigationBloc.add(const ClearNavigation());
        },
        onDismissed: () => isTripSummaryShown = false,
      );
    }
    if (prev.promptBatteryOptimizationOem !=
            curr.promptBatteryOptimizationOem &&
        curr.promptBatteryOptimizationOem != null) {
      HomeDialogCoordinator.showBatteryOptimizationPrompt(
        context: context,
        oemType: curr.promptBatteryOptimizationOem,
        navigationBloc: navigationBloc,
      );
    }
    if (prev.pendingResumeSession != curr.pendingResumeSession &&
        curr.pendingResumeSession != null) {
      HomeDialogCoordinator.showResumeSessionPrompt(
        context: context,
        session: curr.pendingResumeSession,
        navigationBloc: navigationBloc,
      );
    }
    if (prev.errorMessageKey != curr.errorMessageKey &&
        curr.errorMessageKey != null) {
      onError(tr(curr.errorMessageKey!));
    }
  }
}
