import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/styles/themes/default_theme.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/localizations/app_localization.dart';
import 'package:s_map/routers/routers.dart';
import 'package:s_map/services/services.dart';
import 'app_state.dart';

class AppCubit extends Cubit<AppState> {
  AppCubit()
      : super(AppState(
            type: AppStateType.initial,
            appStyle: DefaultTheme(),
            supportedLocale: SupportedLocale.vi));

  @override
  void emit(AppState state) {
    if (isClosed) return;
    super.emit(state);
  }

  void onChangeLocale(SupportedLocale supportedLocale, [BuildContext? context]) {
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
    final service = messagingService ?? FirebaseMessagingService.instance;
    service.fmsCompleter.completeAfter(true);
    service.onAppStartedWithNotification();
  }
}
