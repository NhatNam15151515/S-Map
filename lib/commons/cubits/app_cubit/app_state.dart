import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/styles/themes/dark_theme.dart';
import 'package:s_map/localizations/app_localization.dart';

enum AppStateType { initial, loaded }

class AppState extends Equatable {
  final AppStyle appStyle;
  final SupportedLocale supportedLocale;
  final ThemeMode themeMode;
  final AppStateType type;
  final String appName;

  const AppState({
    required this.appStyle,
    required this.supportedLocale,
    this.themeMode = ThemeMode.system,
    required this.type,
    required this.appName,
  });

  SupportedLocale get dLocale => SupportedLocale.vi;

  bool get isDarkMode =>
      themeMode == ThemeMode.dark ||
      (themeMode == ThemeMode.system && appStyle is DarkTheme);

  AppState copyWith({
    AppStyle? appStyle,
    SupportedLocale? supportedLocale,
    ThemeMode? themeMode,
    AppStateType? type,
    String? appName,
  }) {
    return AppState(
      type: type ?? this.type,
      appStyle: appStyle ?? this.appStyle,
      supportedLocale: supportedLocale ?? this.supportedLocale,
      themeMode: themeMode ?? this.themeMode,
      appName: appName ?? this.appName,
    );
  }

  @override
  List<Object?> get props =>
      [appStyle, supportedLocale, themeMode, type, appName];
}
