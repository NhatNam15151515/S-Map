import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:s_map/commons/utils/app_colors.dart';

/// Semantic ThemeExtension to provide theme-driven colors across Light/Dark modes
/// without hardcoding Color values inside UI widgets.
@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color statsOrange;
  final Color statsBlue;
  final Color statsPink;
  final Color statsSuccess;
  final Color statsSuccessBg;
  final Color onStatsSuccess;
  final Color warning;
  final Color warningBg;

  const AppThemeColors({
    required this.statsOrange,
    required this.statsBlue,
    required this.statsPink,
    required this.statsSuccess,
    required this.statsSuccessBg,
    required this.onStatsSuccess,
    required this.warning,
    required this.warningBg,
  });

  static const light = AppThemeColors(
    statsOrange: AppColors.statsOrange,
    statsBlue: AppColors.statsBlue,
    statsPink: AppColors.statsPink,
    statsSuccess: AppColors.statsSuccess,
    statsSuccessBg: AppColors.statsSuccessBg,
    onStatsSuccess: AppColors.white,
    warning: AppColors.macaw,
    warningBg: AppColors.statsWarningBg,
  );

  static const dark = AppThemeColors(
    statsOrange: AppColors.darkStatsOrange,
    statsBlue: AppColors.darkStatsBlue,
    statsPink: AppColors.darkStatsPink,
    statsSuccess: AppColors.darkStatsSuccess,
    statsSuccessBg: AppColors.darkStatsSuccessBg,
    onStatsSuccess: AppColors.white,
    warning: AppColors.darkWarning,
    warningBg: AppColors.darkWarningBg,
  );

  @override
  AppThemeColors copyWith({
    Color? statsOrange,
    Color? statsBlue,
    Color? statsPink,
    Color? statsSuccess,
    Color? statsSuccessBg,
    Color? onStatsSuccess,
    Color? warning,
    Color? warningBg,
  }) {
    return AppThemeColors(
      statsOrange: statsOrange ?? this.statsOrange,
      statsBlue: statsBlue ?? this.statsBlue,
      statsPink: statsPink ?? this.statsPink,
      statsSuccess: statsSuccess ?? this.statsSuccess,
      statsSuccessBg: statsSuccessBg ?? this.statsSuccessBg,
      onStatsSuccess: onStatsSuccess ?? this.onStatsSuccess,
      warning: warning ?? this.warning,
      warningBg: warningBg ?? this.warningBg,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      statsOrange: Color.lerp(statsOrange, other.statsOrange, t)!,
      statsBlue: Color.lerp(statsBlue, other.statsBlue, t)!,
      statsPink: Color.lerp(statsPink, other.statsPink, t)!,
      statsSuccess: Color.lerp(statsSuccess, other.statsSuccess, t)!,
      statsSuccessBg: Color.lerp(statsSuccessBg, other.statsSuccessBg, t)!,
      onStatsSuccess: Color.lerp(onStatsSuccess, other.onStatsSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
    );
  }
}

/// Convenience BuildContext extensions for 100% Theme-based UI styling.
extension AppThemeBuildContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  AppThemeColors get themeColors =>
      Theme.of(this).extension<AppThemeColors>() ?? AppThemeColors.light;

  void safePop<T>([T? result]) {
    try {
      pop(result);
    } catch (_) {
      Navigator.of(this).pop(result);
    }
  }
}
