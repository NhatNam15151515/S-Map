import 'package:flutter/material.dart';
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
  final Color warning;
  final Color warningBg;

  const AppThemeColors({
    required this.statsOrange,
    required this.statsBlue,
    required this.statsPink,
    required this.statsSuccess,
    required this.statsSuccessBg,
    required this.warning,
    required this.warningBg,
  });

  static const light = AppThemeColors(
    statsOrange: AppColors.statsOrange,
    statsBlue: AppColors.statsBlue,
    statsPink: AppColors.statsPink,
    statsSuccess: AppColors.statsSuccess,
    statsSuccessBg: AppColors.statsSuccessBg,
    warning: AppColors.macaw,
    warningBg: Color(0xFFFFF8E1),
  );

  static const dark = AppThemeColors(
    statsOrange: Color(0xFFFFB74D),
    statsBlue: Color(0xFF64B5F6),
    statsPink: Color(0xFFF06292),
    statsSuccess: Color(0xFF81C784),
    statsSuccessBg: Color(0xFF1B5E20),
    warning: Color(0xFFFFD54F),
    warningBg: Color(0xFF5D4037),
  );

  @override
  AppThemeColors copyWith({
    Color? statsOrange,
    Color? statsBlue,
    Color? statsPink,
    Color? statsSuccess,
    Color? statsSuccessBg,
    Color? warning,
    Color? warningBg,
  }) {
    return AppThemeColors(
      statsOrange: statsOrange ?? this.statsOrange,
      statsBlue: statsBlue ?? this.statsBlue,
      statsPink: statsPink ?? this.statsPink,
      statsSuccess: statsSuccess ?? this.statsSuccess,
      statsSuccessBg: statsSuccessBg ?? this.statsSuccessBg,
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
}
