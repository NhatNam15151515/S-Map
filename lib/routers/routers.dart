import 'dart:async';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/enums/enums.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/screens/auth/login_screen.dart';
import 'package:s_map/screens/initial/initial_screen.dart';
import 'package:s_map/screens/onboarding/onboarding_screen.dart';
import 'package:s_map/screens/main/full_image.dart';
import 'package:s_map/screens/main/home/home_screen.dart';
import 'package:s_map/screens/main/main_screen.dart';
import 'package:s_map/screens/main/notification/notification_screen.dart';
import 'package:s_map/screens/main/saved/saved_screen.dart';
import 'package:s_map/screens/main/user/user_screen.dart';
import 'package:s_map/screens/search/search_screen.dart';
import 'package:s_map/screens/navigation/navigation_screen.dart';
import 'package:s_map/screens/route_drawing/route_drawing_screen.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/stats/stats_screen.dart';
import 'package:s_map/screens/stats/trip_detail_screen.dart';
import 'package:s_map/screens/settings/settings_screen.dart';
import 'package:s_map/screens/settings/offline_regions/offline_regions_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/services/services.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'app_routes.dart';

export 'app_routes.dart';

class Routes extends NavigatorObserver {
  static Routes instance = Routes();
  Completer<bool> routeMounted = Completer();

  final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey();

  BuildContext get context => rootNavigatorKey.currentContext!;

  late final GoRouter router;

  void popUntil(String routeName) {
    Routes.instance.rootNavigatorKey.currentState?.popUntil((route) =>
        route.settings.name ==
        (routeName.startsWith("/") ? routeName : "/$routeName"));
  }

  void popUntilFirst() {
    Routes.instance.rootNavigatorKey.currentState
        ?.popUntil((route) => route.isFirst);
  }

  Routes() {
    FirebaseMessagingService.loadingOverlayHandler = showLoadingDepend;
    router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: AppRoutes.initial,
      errorBuilder: (context, state) {
        return const SizedBox();
      },
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.initial,
          builder: (context, state) => const InitialScreen(),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: AppRoutes.onboarding,
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: AppRoutes.search,
          builder: (context, state) {
            final extra = state.extra;
            final userLocation = extra is LatLng ? extra : null;
            return SearchScreen(userLocation: userLocation);
          },
        ),
        GoRoute(
          path: AppRoutes.navigation,
          builder: (context, state) => const NavigationScreen(),
        ),
        GoRoute(
          path: AppRoutes.routeDrawing,
          builder: (context, state) => const RouteDrawingScreen(),
        ),
        GoRoute(
          path: AppRoutes.stats,
          builder: (context, state) => const StatsScreen(),
        ),
        GoRoute(
          path: AppRoutes.tripDetail,
          builder: (context, state) {
            final trip = state.extra;
            if (trip is! TripRecordModel) {
              return Scaffold(
                body: Center(
                  child: Text(tr(LocaleKeys.stats_dashboard_invalid_trip_data)),
                ),
              );
            }
            return TripDetailScreen(trip: trip);
          },
        ),
        GoRoute(
          path: AppRoutes.settings,
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: AppRoutes.offlineRegions,
          builder: (context, state) => const OfflineRegionsScreen(),
        ),
        GoRoute(
          path: AppRoutes.fullImage,
          builder: (context, state) =>
              FullImageScreen(args: state.extra as AppImage),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return MainScreen(navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: AppRoutes.home,
                  builder: (context, state) => const HomeScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.saved,
                  builder: (context, state) => const SavedScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: AppRoutes.notification,
                  builder: (context, state) => const NotificationScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: AppRoutes.user,
                  builder: (context, state) => const UserScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  void applyWithAuthState(AuthCubit authCubit) {
    authCubit.stream.listen((event) async {
      await routeMounted.future;
      switch (event.type) {
        case AuthStateType.unAuthenticated:
          if (context.mounted) context.go(AppRoutes.login);
          break;
        case AuthStateType.onboarding:
          if (context.mounted) context.go(AppRoutes.onboarding);
          break;
        case AuthStateType.authenticated:
          if (context.mounted) context.go(AppRoutes.home);
          break;
        default:
          break;
      }
    });
  }

  OverlayState? get _appOverlayState => rootNavigatorKey.currentState?.overlay;

  AppStyle get styles => AppStyle.of(context);

  OverlayEntry showLoadingOverlay() {
    OverlayEntry overlayEntry = OverlayEntry(builder: (context) {
      return Container(
        color: Colors.transparent,
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Shimmer.fromColors(
            baseColor: AppColors.white,
            highlightColor: AppColors.white,
            child: AppAsset.logo.image.build(
              size: const Size(35, 35),
              // color: _styles.whiteColor,
            ),
          ),
        ),
      );
    });

    _appOverlayState?.insert(overlayEntry);
    return overlayEntry;
  }

  Future<void> showLoadingDepend(Future future) async {
    final overlay = showLoadingOverlay();

    try {
      await future;
    } catch (e) {
      debugPrint(e.toString());
    }
    overlay.remove();
  }

  Future<void> showMaintenanceAppDialog() async {
    final res = RemoteConfigService().maintenance;
    if (!res) return;

    final Completer removeUpdateOverlayCompleter = Completer();
    OverlayEntry overlayEntry = OverlayEntry(builder: (context) {
      return MaintenancePopup(
        removeUpdateOverlayCompleter: removeUpdateOverlayCompleter,
      );
    });
    _appOverlayState?.insert(overlayEntry);
    await removeUpdateOverlayCompleter.future;
    overlayEntry.remove();
  }

  Future<void> showUpdateAppDialog() async {
    final res = await RemoteConfigService().mustUpdate();
    if (!res) return;

    final Completer removeUpdateOverlayCompleter = Completer();
    OverlayEntry overlayEntry = OverlayEntry(builder: (context) {
      return UpdatePopup(
        removeUpdateOverlayCompleter: removeUpdateOverlayCompleter,
      );
    });
    _appOverlayState?.insert(overlayEntry);
    await removeUpdateOverlayCompleter.future;
    overlayEntry.remove();
  }
}
