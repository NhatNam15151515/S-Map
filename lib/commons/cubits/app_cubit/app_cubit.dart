import 'package:s_map/commons/styles/themes/default_theme.dart';
import 'package:s_map/repos/notification_repos.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/cubits/auth_cubit/auth_cubit.dart';
import 'package:s_map/localizations/app_localization.dart';
import 'package:s_map/repos/auth_repos.dart';
import 'package:s_map/routers/routers.dart';
import 'app_state.dart';

class AppReposProvider {
  final AuthRepos authRepos = AuthReposImpl();
  final NotificationRepos notiRepos = NotificationReposImpl();
}

class AppCubit extends Cubit<AppState> {
  final AppReposProvider appReposProvider = AppReposProvider();

  AppCubit()
      : super(AppState(
            type: AppStateType.initial,
            appStyle: DefaultTheme(),
            supportedLocale: SupportedLocale.vi));

  BuildContext get appContext => Routes.instance.context;

  void initInterceptor(dynamic authToken, AuthCubit authCubit) {
    // Legacy HTTP interceptors removed - app now communicates directly via Firebase / Firestore
  }

  void onChangeLocale(SupportedLocale supportedLocale) {
    emit(state.copyWith(supportedLocale: supportedLocale));
    appContext.setLocale(supportedLocale.locale);
  }

  Future initMetaData() async {
    await Routes.instance.showMaintenanceAppDialog();
  }
}
