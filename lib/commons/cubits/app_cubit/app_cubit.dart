import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/styles/themes/default_theme.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/localizations/app_localization.dart';
import 'package:s_map/routers/routers.dart';
import 'app_state.dart';

class AppCubit extends Cubit<AppState> {
  /// Global service resolvers set during app initialization
  static IPackageInfoService? defaultPackageInfoService;
  static IFirebaseMessagingService? defaultMessagingService;

  AppCubit({String? appName, IPackageInfoService? packageInfoService})
      : super(AppState(
            type: AppStateType.initial,
            appStyle: DefaultTheme(),
            appName: appName ??
                (packageInfoService ?? defaultPackageInfoService)?.appName ??
                'S-Map',
            supportedLocale: SupportedLocale.vi)) {
    // Register resolver to break circular dependency:
    // styles.dart ↔ app_cubit.dart ↔ default_theme.dart
    AppStyle.setResolver(
      (context) => BlocProvider.of<AppCubit>(context).state.appStyle,
    );
  }

  @override
  void emit(AppState state) {
    if (isClosed) return;
    super.emit(state);
  }

  void onChangeLocale(SupportedLocale supportedLocale,
      [BuildContext? context]) {
    emit(state.copyWith(supportedLocale: supportedLocale));
    if (context != null) {
      context.setLocale(supportedLocale.locale);
    } else {
      Routes.instance.context.setLocale(supportedLocale.locale);
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

