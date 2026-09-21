import 'package:flutter/material.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/main/home/widgets/widgets.dart';

/// Điều phối hiển thị các dialog và modal liên quan đến Navigation trên Home Screen.
///
/// Giúp tách logic presentation & flow prompt ra khỏi [HomeScreenContent].
class HomeDialogCoordinator {
  const HomeDialogCoordinator._();

  /// Hiển thị prompt tối ưu hóa pin cho các dòng thiết bị OEM đặc thù.
  static Future<void> showBatteryOptimizationPrompt({
    required BuildContext context,
    required dynamic oemType,
    required NavigationBloc navigationBloc,
  }) async {
    if (oemType == null) return;
    final result = await BatteryOptimizationDialog.show(
      context,
      oemType: oemType,
      onAllow: () {
        navigationBloc.add(const AllowBatteryOptimization());
      },
      onSkip: () {
        navigationBloc.add(const SkipBatteryOptimization());
      },
    );
    if (result == null && context.mounted) {
      navigationBloc.add(const DismissBatteryOptimizationPrompt());
    }
  }

  /// Hiển thị prompt khôi phục phiên dẫn đường trước đó nếu app bị restart.
  static Future<void> showResumeSessionPrompt({
    required BuildContext context,
    required dynamic session,
    required NavigationBloc navigationBloc,
  }) async {
    if (session == null) return;
    final result = await ResumeTripDialog.show(
      context,
      snapshot: session,
      onResume: () {
        navigationBloc.add(ResumeNavigation(session));
      },
      onDiscard: () {
        navigationBloc.add(const DiscardActiveSession());
      },
    );
    if (result == null && context.mounted) {
      navigationBloc.add(const DiscardActiveSession());
    }
  }

  /// Hiển thị BottomSheet tóm tắt chuyến đi khi người dùng đến đích hoặc kết thúc hành trình.
  static Future<void> showTripSummaryModal({
    required BuildContext context,
    required TripSummary summary,
    required VoidCallback onDone,
    required VoidCallback onDismissed,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => TripSummaryBottomSheet(
        summary: summary,
        onDone: () {
          Navigator.of(modalContext).pop();
          onDone();
        },
      ),
    ).whenComplete(onDismissed);
  }
}
