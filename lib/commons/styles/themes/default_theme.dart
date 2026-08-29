import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:flutter/material.dart';

class DefaultTheme extends AppStyle {
  static final DefaultTheme instance = DefaultTheme();

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
        surfaceContainer: AppColors.white,
        surfaceContainerHighest: AppColors.surfaceContainerHighest,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        outline: AppColors.outlineVariant,
        outlineVariant: AppColors.outlineVariant,
      );


  @override
  InputBorder get defaultBorder => OutlineInputBorder(
        borderSide: const BorderSide(
          width: 1,
          color: AppColors.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(12),
      );

  @override
  InputBorder get errorBorder => OutlineInputBorder(
        borderSide: const BorderSide(
          width: 1.5,
          color: AppColors.googleRed,
        ),
        borderRadius: BorderRadius.circular(12),
      );

  @override
  BoxDecoration get searchContainer => BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      );

  @override
  ThemeData get light => ThemeData(
        brightness: Brightness.light,
        colorScheme: colorScheme,
        useMaterial3: true,
        extensions: const [AppThemeColors.light],
        unselectedWidgetColor: AppColors.onSurfaceVariant,
        scaffoldBackgroundColor: AppColors.surfaceDim,
        fontFamilyFallback: const ['Montserrat', 'Roboto', 'sans-serif'],

        cardTheme: CardThemeData(

          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          surfaceTintColor: Colors.transparent,
          color: AppColors.white,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.googleDarkText,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          backgroundColor: AppColors.white,
          selectedItemColor: AppColors.sMapTeal,
          unselectedItemColor: AppColors.onSurfaceVariant,
          selectedLabelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.sMapTeal,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: textButtonStyle,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: buttonStyle,
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: outlineButtonStyle,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceContainer,
          hintStyle: AppColors.onSurfaceVariant.textTheme.textStyle.copyWith(
            fontSize: 14,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.sMapTeal,
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.googleRed,
              width: 1.5,
            ),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.googleDarkText,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          surfaceTintColor: Colors.transparent,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.outlineVariant,
          thickness: 0.5,
          space: 0,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surfaceContainer,
          selectedColor: AppColors.sMapLightTeal,
          labelStyle: AppColors.googleDarkText.textTheme.boldStyle
              .copyWith(fontSize: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      );

  @override
  Color get blackTextColor => AppColors.googleDarkText;

  @override
  Color get whiteTextColor => AppColors.white;

  @override
  List<Color> get greysTextColor => [
        AppColors.onSurfaceVariant, //600
        AppColors.argent, //500
        AppColors.doveGrey, //400
        AppColors.outlineVariant, //200
        AppColors.whiteOut, //50
      ];

  @override
  ButtonStyle get buttonStyle => ButtonStyle(
        backgroundColor: WidgetStateProperty.all(colorScheme.primary),
        foregroundColor: WidgetStateProperty.all(AppColors.white),
        elevation: WidgetStateProperty.all(0),
        minimumSize: WidgetStateProperty.all(const Size(0, 48)),
        padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
        shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
        overlayColor: WidgetStatePropertyAll(AppColors.white.withAlpha(30)),
      );

  @override
  ButtonStyle get outlineButtonStyle => ButtonStyle(
        backgroundColor: WidgetStateProperty.all(AppColors.white),
        foregroundColor: WidgetStateProperty.all(AppColors.googleDarkText),
        elevation: WidgetStateProperty.all(0),
        minimumSize: WidgetStateProperty.all(const Size(0, 48)),
        padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
        shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
        side: WidgetStateProperty.all(const BorderSide(
          color: AppColors.outlineVariant,
          width: 1,
        )),
      );

  @override
  ButtonStyle get textButtonStyle => ButtonStyle(
        minimumSize: WidgetStateProperty.all(Size.zero),
        padding: WidgetStateProperty.all(EdgeInsets.zero),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: WidgetStateProperty.all(AppColors.sMapTeal),
      );

  @override
  ButtonStyle get whiteButton => buttonStyle
      .mergeBackgroundColor(
        Colors.white,
      )
      .copyWith(
        foregroundColor: const WidgetStatePropertyAll(AppColors.googleDarkText),
        overlayColor: WidgetStatePropertyAll(AppColors.grey.withAlpha(26)),
      );
}

extension ButtonStyleExtension on ButtonStyle {
  ButtonStyle mergeBackgroundColor(Color? color) => color == null
      ? this
      : copyWith(
          backgroundColor: WidgetStateProperty.all(color),
        );
  ButtonStyle mergeOutlineColor(Color? color) => color == null
      ? this
      : copyWith(
          side: WidgetStateProperty.all(BorderSide(
          color: color,
          width: 1,
        )));
}
