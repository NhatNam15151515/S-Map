import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:s_map/app.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/flavor/flavor.dart';
import 'package:s_map/repos/repos.dart';
import 'dart:io';
import 'package:s_map/services/services.dart';

void main() async {
  stderr.writeln('🚀 [S-MAP] bootstrap started');
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  
  // Preserve native splash during async initialization
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Safeguard: Always dismiss native splash after at most 3.5 seconds
  // in case any service initialization stalls or throws unexpectedly.
  Future.delayed(const Duration(milliseconds: 3500), () {
    try {
      FlutterNativeSplash.remove();
    } catch (_) {}
  });

  // Setup default service resolvers & AppReposProvider (Composition Root)
  CustomRouteServiceImpl.defaultFireStoreService = FireStoreService.instance;
  CustomRouteServiceImpl.defaultAuthService = FirebaseAuthService.instance;
  AppReposProvider.init(routingService: RoutingServiceImpl.instance);
  MapDisplayCubit.defaultLocationService = LocationService.instance;
  MapDisplayCubit.defaultCompassService = CompassService.instance;
  MapDisplayCubit.defaultMapStyleService = MapStyleService.instance;
  MapDisplayCubit.defaultDarkModeResolver = () {
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  };

  MapExploreCubit.defaultFireStoreService = FireStoreService.instance;
  RecentSearchServiceImpl.defaultFireStoreService = FireStoreService.instance;
  RecentSearchServiceImpl.defaultAuthService = FirebaseAuthService.instance;
  FavoritesServiceImpl.defaultFireStoreService = FireStoreService.instance;
  FavoritesServiceImpl.defaultAuthService = FirebaseAuthService.instance;
  VisitedPoiServiceImpl.defaultFireStoreService = FireStoreService.instance;
  VisitedPoiServiceImpl.defaultAuthService = FirebaseAuthService.instance;
  FavoritesCubit.defaultFavoritesService = FavoritesServiceImpl.instance;
  AppCubit.defaultMessagingService = FirebaseMessagingService.instance;
  AppCubit.defaultSharedPreferences = AppSharedPreferences();
  AuthCubit.defaultSharedPreferences = AppSharedPreferences();
  AuthCubit.defaultSecureStorage = AppSecureStorage.instance;
  AuthCubit.defaultLocalAuthService = FlutterLocalAuth.instance;
  AuthCubit.defaultAnalyticsService = FirebaseAnalyticsService();
  RoutePreviewCubit.defaultLocationService = LocationService.instance;
  NavigationBloc.defaultLocationService = LocationService.instance;
  NavigationBloc.defaultDeviceInfoService = DeviceInfoService.instance;
  NavigationBloc.defaultActiveTripService = ActiveTripServiceImpl.instance;
  NavigationBloc.defaultVisitedPoiService = VisitedPoiServiceImpl.instance;
  ListenComingNotification.messagingServiceResolver = FirebaseMessagingService.instance;

  try {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox<dynamic>(RegionDownloadServiceImpl.boxName),
      Hive.openBox<dynamic>(RecentSearchServiceImpl.boxName),
      Hive.openBox<dynamic>(FavoritesServiceImpl.boxName),
      Hive.openBox<dynamic>(VisitedPoiServiceImpl.boxName),
    ]);
  } catch (e) {
    debugPrint("Hive initialization notice: $e");
  }

  try {
    await EasyLocalization.ensureInitialized();
  } catch (e) {
    debugPrint("EasyLocalization notice: $e");
  }

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint("Firebase.initializeApp notice: $e");
  }

  try {
    if (Firebase.apps.isNotEmpty) {
      await FirebaseMessagingService.instance.init();
      await RemoteConfigService().initialize();
      FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(kReleaseMode && Flavor.instance.isProd);
      FlutterError.onError = (errorDetails) {
        FirebaseCrashlytics.instance.recordFlutterError(errorDetails);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }
  } catch (e) {
    debugPrint("Firebase services setup notice: $e");
  }

  LicenseRegistry.addLicense(() async* {
    try {
      final license = await rootBundle.loadString('assets/fonts/OFL.txt');
      yield LicenseEntryWithLineBreaks(['assets', 'fonts'], license);
    } catch (_) {}
  });

  try {
    await LocalNotificationService.instance.init();
  } catch (e) {
    debugPrint("LocalNotificationService notice: $e");
  }

  try {
    await MapStyleService.instance.init();
  } catch (e) {
    debugPrint("MapStyleService notice: $e");
  }

  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (_) {}

  ThemeMode initialThemeMode = ThemeMode.system;
  try {
    final savedThemeStr = await AppSharedPreferences().getThemeMode().timeout(
      const Duration(seconds: 1),
      onTimeout: () => null,
    );
    if (savedThemeStr != null) {
      initialThemeMode = AppCubit.parseThemeMode(savedThemeStr);
    }
  } catch (_) {}

  stderr.writeln('🚀 [S-MAP] calling runApp with theme: $initialThemeMode');
  runApp(MyApp(initialThemeMode: initialThemeMode));
}
