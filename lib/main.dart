import 'package:s_map/services/bundle_load_service.dart';
import 'package:s_map/services/map_style_service.dart';
import 'package:s_map/services/local_notification_service.dart';
import 'package:s_map/services/firebase_messaging_services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:s_map/app.dart';
import 'package:s_map/services/remote_config_service.dart';
import 'package:s_map/flavor/flavor.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

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
  BundleLoadService.instance.init();
  await MapStyleService.instance.init();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}
