import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/cubits/auth_cubit/auth_fallbacks.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/styles/themes/dark_theme.dart';
import 'package:s_map/commons/styles/themes/default_theme.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/localizations/app_localization.dart';
import 'package:s_map/routers/routers.dart';
import 'app_state.dart';

class AppCubit extends Cubit<AppState> {
  final ISharedPreferences _sharedPreferences;

  /// Global service resolvers set during app initialization
  static IPackageInfoService? defaultPackageInfoService;
  static IFirebaseMessagingService? defaultMessagingService;
  static ISharedPreferences? defaultSharedPreferences;

  AppCubit({
    String? appName,
    IPackageInfoService? packageInfoService,
    ISharedPreferences? sharedPreferences,
  })  : _sharedPreferences = sharedPreferences ??
            defaultSharedPreferences ??
            NoOpSharedPreferences(),
        super(AppState(
          type: AppStateType.initial,
          appStyle: DefaultTheme(),
          themeMode: ThemeMode.system,
          appName: appName ??
              (packageInfoService ?? defaultPackageInfoService)?.appName ??
              'S-Map',
          supportedLocale: SupportedLocale.vi,
        )) {
    // Register resolver to break circular dependency:
    // styles.dart ↔ app_cubit.dart ↔ default_theme.dart
    AppStyle.setResolver(
      (context) => BlocProvider.of<AppCubit>(context).state.appStyle,
    );
    initTheme();
  }

  @override
  void emit(AppState state) {
    if (isClosed) return;
    super.emit(state);
  }

  Future<void> initTheme() async {
    try {
      final savedMode = await _sharedPreferences.getThemeMode();
      if (savedMode != null) {
        final mode = _parseThemeMode(savedMode);
        final style = mode == ThemeMode.dark ? DarkTheme() : DefaultTheme();
        emit(state.copyWith(
          themeMode: mode,
          appStyle: style,
        ));
      }
    } catch (_) {}
  }

  void onChangeThemeMode(ThemeMode mode) {
    final style = mode == ThemeMode.dark ? DarkTheme() : DefaultTheme();
    emit(state.copyWith(
      themeMode: mode,
      appStyle: style,
    ));
    _sharedPreferences.saveThemeMode(_themeModeToString(mode));
  }

  void toggleDarkMode(bool isDark) {
    onChangeThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }

  static ThemeMode _parseThemeMode(String modeStr) {
    switch (modeStr) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  static String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
    }
  }

  void onChangeLocale(SupportedLocale supportedLocale,
      [BuildContext? context]) {
    emit(state.copyWith(supportedLocale: supportedLocale));
    if (context != null) {
      context.setLocale(supportedLocale.locale);
    } else {
      try {
        final ctx = Routes.instance.rootNavigatorKey.currentContext;
        if (ctx != null) {
          ctx.setLocale(supportedLocale.locale);
        }
      } catch (_) {}
    }
  }

  Future<void> initMetaData() async {
    await Routes.instance.showMaintenanceAppDialog();
  }

  void onMainScreenMounted({IFirebaseMessagingService? messagingService}) {
    final service = messagingService ?? defaultMessagingService;
    if (service != null) {
      if (!service.fmsCompleter.isCompleted) {
        service.fmsCompleter.complete(true);
      }
      service.onAppStartedWithNotification();
    }
  }
}
