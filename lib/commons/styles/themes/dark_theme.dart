import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/styles/themes/default_theme.dart';
import 'package:s_map/commons/utils/app_colors.dart';

class DarkTheme extends AppStyle {
  @override
  ColorScheme get colorScheme => const ColorScheme(
        brightness: Brightness.dark,
        primary: AppColors.sMapTeal,
        onPrimary: AppColors.white,
        secondary: AppColors.sMapDarkTeal,
        onSecondary: AppColors.white,
        error: AppColors.googleRed,
        onError: AppColors.white,
        surface: Color(0xFF1E1E1E),
        onSurface: Color(0xFFE8EAED),
        surfaceContainerHighest: Color(0xFF2D2D2D),
        outline: Color(0xFF3C4043),
      );

  @override
  InputBorder get defaultBorder => OutlineInputBorder(
        borderSide: const BorderSide(
          width: 1,
          color: Color(0xFF3C4043),
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
        color: const Color(0xFF242424),
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
        scaffoldBackgroundColor: const Color(0xFF121212),
        fontFamily: 'Montserrat',
        cardTheme: CardThemeData(
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          surfaceTintColor: Colors.transparent,
          color: const Color(0xFF1E1E1E),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF2D2D2D),
          contentTextStyle: const TextStyle(
            fontFamily: 'Montserrat',
            color: Color(0xFFE8EAED),
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
          backgroundColor: Color(0xFF1E1E1E),
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
          fillColor: const Color(0xFF242424),
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
          backgroundColor: Color(0xFF121212),
          foregroundColor: Color(0xFFE8EAED),
          elevation: 0,
          scrolledUnderElevation: 0.5,
          surfaceTintColor: Colors.transparent,
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF3C4043),
          thickness: 0.5,
          space: 0,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF242424),
          selectedColor: AppColors.sMapDarkTeal,
          labelStyle: const TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w500,
            color: Color(0xFFE8EAED),
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
  Color get blackTextColor => const Color(0xFFE8EAED);

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
        backgroundColor: WidgetStateProperty.all(const Color(0xFF1E1E1E)),
        foregroundColor: WidgetStateProperty.all(const Color(0xFFE8EAED)),
        elevation: WidgetStateProperty.all(0),
        minimumSize: WidgetStateProperty.all(const Size(0, 48)),
        padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
        shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
        side: WidgetStateProperty.all(const BorderSide(
          color: Color(0xFF3C4043),
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
        const Color(0xFF2A2A2A),
      )
      .copyWith(
        foregroundColor: const WidgetStatePropertyAll(Color(0xFFE8EAED)),
        overlayColor: WidgetStatePropertyAll(AppColors.grey.withAlpha(26)),
      );
}
