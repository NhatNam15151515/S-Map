import 'package:flutter/material.dart';

import '../utils/app_colors.dart';
import 'font_weight.dart';
export 'font_weight.dart';

/// Typedef for a function that resolves [AppStyle] from [BuildContext].
/// Injected at app startup to avoid circular imports between the styles
/// layer and the cubits layer.
typedef AppStyleResolver = AppStyle Function(BuildContext context);

abstract class AppStyle {
  ThemeData get light;
  ColorScheme get colorScheme;
  Color get blackTextColor;
  Color get whiteTextColor;
  List<Color> get greysTextColor;
  InputBorder get defaultBorder;
  InputBorder get errorBorder;
  BoxDecoration get searchContainer;

  ButtonStyle get textButtonStyle;
  ButtonStyle get buttonStyle;
  ButtonStyle get outlineButtonStyle;

  ButtonStyle get whiteButton;

  // Static resolver & fallback style – injected from default_theme or AppCubit.
  // This completely eliminates circular dependencies between styles and themes.
  static AppStyleResolver? _resolver;
  static AppStyle? defaultStyle;

  /// Must be called once during app bootstrap (e.g., inside main.dart or AppCubit)
  /// before any call to [AppStyle.of].
  static void setResolver(AppStyleResolver resolver) {
    _resolver = resolver;
  }

  /// Returns the current [AppStyle] from the nearest AppCubit in the widget tree,
  /// with a graceful fallback for widget tests and previews.
  static AppStyle of(BuildContext context) {
    if (_resolver != null) {
      try {
        return _resolver!(context);
      } catch (_) {}
    }
    return defaultStyle ?? _fallbackInstance;
  }

  static final AppStyle _fallbackInstance = _FallbackAppStyle();
}

class _FallbackAppStyle extends AppStyle {
  @override
  ThemeData get light => ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
      );

  @override
  ColorScheme get colorScheme => const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.sMapTeal,
        onPrimary: AppColors.white,
        secondary: AppColors.sMapDarkTeal,
        onSecondary: AppColors.white,
        error: AppColors.googleRed,
        onError: AppColors.white,
        surface: AppColors.white,
        onSurface: AppColors.googleDarkText,
      );

  @override
  Color get blackTextColor => AppColors.googleDarkText;

  @override
  Color get whiteTextColor => AppColors.white;

  @override
  List<Color> get greysTextColor => const [
        AppColors.onSurfaceVariant,
        AppColors.argent,
        AppColors.doveGrey,
        AppColors.outlineVariant,
        AppColors.whiteOut,
      ];

  @override
  InputBorder get defaultBorder => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.outlineVariant),
      );

  @override
  InputBorder get errorBorder => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.googleRed, width: 1.5),
      );

  @override
  BoxDecoration get searchContainer => BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(28),
      );

  @override
  ButtonStyle get buttonStyle => ButtonStyle(
        backgroundColor: WidgetStateProperty.all(AppColors.sMapTeal),
        foregroundColor: WidgetStateProperty.all(AppColors.white),
      );

  @override
  ButtonStyle get outlineButtonStyle => ButtonStyle(
        backgroundColor: WidgetStateProperty.all(AppColors.white),
        foregroundColor: WidgetStateProperty.all(AppColors.googleDarkText),
        side: WidgetStateProperty.all(
          const BorderSide(color: AppColors.outlineVariant),
        ),
      );

  @override
  ButtonStyle get textButtonStyle => ButtonStyle(
        foregroundColor: WidgetStateProperty.all(AppColors.sMapTeal),
      );

  @override
  ButtonStyle get whiteButton => buttonStyle.copyWith(
        backgroundColor: WidgetStateProperty.all(AppColors.white),
        foregroundColor: WidgetStateProperty.all(AppColors.googleDarkText),
      );
}

class AppTextTheme {
  final Color color;

  AppTextTheme(this.color);

  TextStyle get mainStyle => const TextStyle().merge(color.toTextStyle);

  TextStyle get textStyle =>
      mainStyle.copyWith(fontWeight: AppFontWeight.regular.weight);

  TextStyle get boldStyle =>
      mainStyle.copyWith(fontWeight: AppFontWeight.medium.weight);

  TextStyle get subTitleStyle =>
      mainStyle.copyWith(fontWeight: AppFontWeight.semiBold.weight);

  TextStyle get textTitleStyle =>
      mainStyle.copyWith(fontWeight: AppFontWeight.bold.weight);

  // Extended text styles for Material 3 design
  TextStyle get captionStyle => mainStyle.copyWith(
        fontWeight: AppFontWeight.regular.weight,
        fontSize: 12,
      );

  TextStyle get overlineStyle => mainStyle.copyWith(
        fontWeight: AppFontWeight.medium.weight,
        fontSize: 10,
        letterSpacing: 1.5,
      );

  TextStyle get headlineStyle => mainStyle.copyWith(
        fontWeight: AppFontWeight.bold.weight,
        fontSize: 24,
      );

  TextStyle get displayStyle => mainStyle.copyWith(
        fontWeight: AppFontWeight.bold.weight,
        fontSize: 32,
      );
}

extension ToAppTextTheme on Color {
  AppTextTheme get textTheme => AppTextTheme(this);

  LinearGradient get gradientItemColor => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          withAlpha(50),
          withAlpha(0),
        ],
      );

  LinearGradient get darkerGradientItemColor => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          withAlpha(0),
          withAlpha(80),
        ],
      );
}
