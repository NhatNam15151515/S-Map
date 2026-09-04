import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/styles/themes/themes.dart';
import 'package:s_map/generated/codegen_loader.g.dart';
import 'package:s_map/localizations/app_localization.dart';
import 'package:s_map/repos/repos.dart';
import 'package:s_map/routers/routers.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:s_map/services/services.dart';

class MyApp extends StatefulWidget {
  final ThemeMode initialThemeMode;
  const MyApp({super.key, this.initialThemeMode = ThemeMode.system});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppCubit appCubit;
  late AuthCubit authCubit;
  late MapDisplayCubit mapDisplayCubit;
  late NotificationCubit notificationCubit;
  late FavoritesCubit favoritesCubit;
  late SavedRoutesCubit savedRoutesCubit;
  late RoutePreviewCubit routePreviewCubit;
  late NavigationBloc navigationBloc;
  late SyncBloc syncBloc;

  @override
  void initState() {
    super.initState();
    appCubit = AppCubit(initialThemeMode: widget.initialThemeMode);
    authCubit = AuthCubit();
    mapDisplayCubit = MapDisplayCubit();
    notificationCubit = NotificationCubit();
    favoritesCubit = FavoritesCubit();
    savedRoutesCubit = SavedRoutesCubit();
    routePreviewCubit = RoutePreviewCubit(
      routingRepository: AppReposProvider.instance.routingRepos,
    );
    navigationBloc = NavigationBloc(
      routingRepository: AppReposProvider.instance.routingRepos,
      tripRepository: AppReposProvider.instance.tripRepos,
    );
    syncBloc = SyncBloc(
      authService: FirebaseAuthService.instance,
      authRepos: AppReposProvider.instance.authRepos,
      autoStartOnQueue: true,
    );
    Routes.instance.applyWithAuthState(authCubit);
    authCubit.onAppStarted();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        FlutterNativeSplash.remove();
      } catch (_) {}
    });

    // Fallback: đảm bảo Native Splash luôn được gỡ bỏ sau tối đa 2.5 giây
    Future.delayed(const Duration(milliseconds: 2500), () {
      try {
        FlutterNativeSplash.remove();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    favoritesCubit.close();
    mapDisplayCubit.close();
    savedRoutesCubit.close();
    routePreviewCubit.close();
    navigationBloc.close();
    syncBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: appCubit),
        BlocProvider.value(value: authCubit),
        BlocProvider.value(value: mapDisplayCubit),
        BlocProvider.value(value: notificationCubit),
        BlocProvider.value(value: favoritesCubit),
        BlocProvider.value(value: savedRoutesCubit),
        BlocProvider.value(value: routePreviewCubit),
        BlocProvider.value(value: navigationBloc),
        BlocProvider.value(value: syncBloc),
      ],
      child: BlocListener<AuthCubit, AuthState>(
        bloc: authCubit,
        listenWhen: (previous, current) =>
            previous.type != current.type && current.isAuthenticated,
        listener: (context, state) {
          // Firebase Auth can finish restoring/signing in after the first
          // FavoritesCubit load. Reload here so cloud-saved POIs appear on
          // the map and in the Saved screen immediately.
          favoritesCubit.loadFavorites();
          savedRoutesCubit.loadSavedRoutes();
          syncBloc.add(const SyncStarted());
        },
        child: BlocBuilder<AppCubit, AppState>(
          bloc: appCubit,
          builder: (context, state) {
            return EasyLocalization(
            useOnlyLangCode: true,
            supportedLocales:
                SupportedLocale.values.map((e) => e.locale).toList(),
            path: SupportedLocale.assetLanguage,
            fallbackLocale: SupportedLocale.vi.locale,
            saveLocale: true,
            useFallbackTranslations: true,
            assetLoader: const CodegenLoader(),
            child: ScreenUtilInit(
              designSize: const Size(428, 989),
              minTextAdapt: true,
              splitScreenMode: true,
              builder: (context, child) {
                return MaterialApp.router(
                  localizationsDelegates: context.localizationDelegates,
                  supportedLocales: context.supportedLocales,
                  theme: DefaultTheme.instance.light,
                  darkTheme: DarkTheme.instance.dark,
                  themeMode: state.themeMode,
                  debugShowCheckedModeBanner: false,
                  locale: context.locale,
                  builder: (context, widget) {
                    final routeMounted = Routes.instance.routeMounted;
                    if (!routeMounted.isCompleted) routeMounted.complete(true);
                    return GestureDetector(
                      onTap: () {
                        WidgetsBinding.instance.focusManager.primaryFocus
                            ?.unfocus();
                      },
                      child: MediaQuery(
                        data: MediaQuery.of(context),
                        child: widget ?? const SizedBox(),
                      ),
                    );
                  },
                  routerConfig: Routes.instance.router,
                );
              },
            ),
            );
          },
        ),
      ),
    );
  }
}
