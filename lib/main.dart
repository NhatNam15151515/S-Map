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
import 'package:s_map/services/services.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Hive.initFlutter();

  // Setup default service resolvers & AppReposProvider (Composition Root)
  AppReposProvider.init(routingService: RoutingServiceImpl.instance);
  MapDisplayCubit.defaultLocationService = LocationService.instance;
  MapDisplayCubit.defaultCompassService = CompassService.instance;
  MapDisplayCubit.defaultMapStyleService = MapStyleService.instance;
  MapDisplayCubit.defaultDarkModeResolver = () {
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  };

  MapExploreCubit.defaultFireStoreService = FireStoreService.instance;
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
  ListenComingNotification.messagingServiceResolver = FirebaseMessagingService.instance;

  await EasyLocalization.ensureInitialized();

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
    final license = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['assets', 'fonts'], license);
  });

  await LocalNotificationService.instance.init();
  await MapStyleService.instance.init();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final savedThemeStr = await AppSharedPreferences().getThemeMode();
  final initialThemeMode = savedThemeStr != null 
      ? AppCubit.parseThemeMode(savedThemeStr) 
      : ThemeMode.system;

  runApp(MyApp(initialThemeMode: initialThemeMode));
}
