import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/styles/themes/default_theme.dart';
import 'package:s_map/commons/utils/app_colors.dart';

class DarkTheme extends AppStyle {
  static final DarkTheme instance = DarkTheme();

  @override
  ColorScheme get colorScheme => const ColorScheme(
        brightness: Brightness.dark,
        primary: AppColors.sMapTeal,
        onPrimary: AppColors.white,
        secondary: AppColors.sMapDarkTeal,
        onSecondary: AppColors.white,
        error: AppColors.googleRed,
        onError: AppColors.white,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkOnSurface,
        surfaceContainerHighest: AppColors.darkSurfaceContainerHighest,
        outline: AppColors.darkOutline,
      );

  @override
  InputBorder get defaultBorder => OutlineInputBorder(
        borderSide: const BorderSide(
          width: 1,
          color: AppColors.darkOutline,
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
        color: AppColors.darkSurfaceContainer,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      );

  @override
  ThemeData get light => ThemeData(
        brightness: Brightness.dark,
        colorScheme: colorScheme,
        useMaterial3: true,
        unselectedWidgetColor: const Color(0xFF9AA0A6),
        scaffoldBackgroundColor: AppColors.darkBackground,
        fontFamily: 'Montserrat',
        cardTheme: CardThemeData(
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          surfaceTintColor: Colors.transparent,
          color: AppColors.darkSurface,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.darkSurfaceContainerHighest,
          contentTextStyle: const TextStyle(
            fontFamily: 'Montserrat',
            color: AppColors.darkOnSurface,
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          backgroundColor: AppColors.darkSurface,
          selectedItemColor: AppColors.sMapTeal,
          unselectedItemColor: Color(0xFF9AA0A6),
          selectedLabelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.sMapTeal,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Color(0xFF9AA0A6),
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
          fillColor: AppColors.darkSurfaceContainer,
          hintStyle: const TextStyle(
            fontFamily: 'Montserrat',
            color: Color(0xFF9AA0A6),
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
          backgroundColor: AppColors.darkBackground,
          foregroundColor: AppColors.darkOnSurface,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          surfaceTintColor: Colors.transparent,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.darkOutline,
          thickness: 0.5,
          space: 0,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.darkSurfaceContainer,
          selectedColor: AppColors.sMapDarkTeal,
          labelStyle: const TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w500,
            color: AppColors.darkOnSurface,
            fontSize: 13,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      );

  @override
  Color get blackTextColor => AppColors.darkOnSurface;

  @override
  Color get whiteTextColor => AppColors.white;

  @override
  List<Color> get greysTextColor => const [
        Color(0xFF9AA0A6),
        Color(0xFF80868B),
        Color(0xFF5F6368),
        Color(0xFF3C4043),
        Color(0xFF202124),
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
        backgroundColor: WidgetStateProperty.all(AppColors.darkSurface),
        foregroundColor: WidgetStateProperty.all(AppColors.darkOnSurface),
        elevation: WidgetStateProperty.all(0),
        minimumSize: WidgetStateProperty.all(const Size(0, 48)),
        padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
        shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
        side: WidgetStateProperty.all(const BorderSide(
          color: AppColors.darkOutline,
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
        AppColors.darkSurfaceContainerHighest,
      )
      .copyWith(
        foregroundColor: const WidgetStatePropertyAll(AppColors.darkOnSurface),
        overlayColor: WidgetStatePropertyAll(AppColors.grey.withAlpha(26)),
      );
}
