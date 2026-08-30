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

class MyApp extends StatefulWidget {
  final ThemeMode initialThemeMode;
  const MyApp({super.key, this.initialThemeMode = ThemeMode.system});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppCubit appCubit;
  late AuthCubit authCubit;
  late NotificationCubit notificationCubit;
  late FavoritesCubit favoritesCubit;
  late SavedRoutesCubit savedRoutesCubit;
  late NavigationBloc navigationBloc;

  @override
  void initState() {
    super.initState();
    appCubit = AppCubit(initialThemeMode: widget.initialThemeMode);
    authCubit = AuthCubit();
    notificationCubit = NotificationCubit();
    favoritesCubit = FavoritesCubit();
    savedRoutesCubit = SavedRoutesCubit();
    navigationBloc = NavigationBloc(
      routingRepository: AppReposProvider.instance.routingRepos,
      tripRepository: AppReposProvider.instance.tripRepos,
    );
    Routes.instance.applyWithAuthState(authCubit);
    authCubit.onAppStarted();
  }

  @override
  void dispose() {
    favoritesCubit.close();
    savedRoutesCubit.close();
    navigationBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: appCubit),
        BlocProvider.value(value: authCubit),
        BlocProvider.value(value: notificationCubit),
        BlocProvider.value(value: favoritesCubit),
        BlocProvider.value(value: savedRoutesCubit),
        BlocProvider.value(value: navigationBloc),
      ],
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
    );
  }
}
