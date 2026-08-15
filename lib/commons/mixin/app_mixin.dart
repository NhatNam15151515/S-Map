import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/app_utils.dart';
import 'package:s_map/commons/utils/popup_utils.dart';
import 'package:s_map/commons/validators/validator.dart';
export 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/repos/repos.dart';
import 'package:s_map/routers/routers.dart';
import 'package:s_map/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

mixin AppMixin {
  AppUtils get appUtils => AppUtils.instance;

  BuildContext get appContext => Routes.instance.context;

  AppCubit get appCubit => appUtils.getCubit<AppCubit>(appContext);

  AuthCubit get authCubit => appUtils.getCubit<AuthCubit>(appContext);

  NotificationCubit get notiCubit =>
      appUtils.getCubit<NotificationCubit>(appContext);

  AppStyle get styles => appCubit.state.appStyle;

  String get appName => appCubit.state.appName;

  Validator get validatorUtils => Validator.instance;

  AppReposProvider get appRepos => AppReposProvider.instance;

  void unFocus() =>
      WidgetsBinding.instance.focusManager.primaryFocus?.unfocus();

  Future showSuccess(String? text) {
    if (text != null) {
      return PopupUtils(appContext).showFlushBar(
          message: text, flushBarStatusType: FlushBarStatusType.succeed);
    }
    return Future.value(false);
  }

  void showValidateMessage(String? text) {
    if (text != null) {
      // return PopupUtils(appContext).showSnackBar(message: text);
    }
  }

  Future showError(String? text) {
    if (text != null) {
      return PopupUtils(appContext).showFlushBar(
          message: text, flushBarStatusType: FlushBarStatusType.error);
    }
    return Future.value(false);
  }

  Future showInfo(String? text) {
    if (text != null) {
      return PopupUtils(appContext).showFlushBar(
          message: text, flushBarStatusType: FlushBarStatusType.info);
    }
    return Future.value(false);
  }

  Future showWarning(String? text) {
    if (text != null) {
      return PopupUtils(appContext).showFlushBar(
          message: text, flushBarStatusType: FlushBarStatusType.warning);
    }
    return Future.value(false);
  }

  Routes get route => Routes.instance;

  double get marginBottomDefault => bottomNavigationBarHeight;

  double get bottomNavigationBarHeight => 110;

  Future showCopied(String copiedContent, {BuildContext? buildContext}) {
    return Clipboard.setData(ClipboardData(text: copiedContent)).then((_) {
      ScaffoldMessenger.of(buildContext ?? appContext)
          .showSnackBar(const SnackBar(
        duration: Duration(milliseconds: 300),
        content: Text(
          "Đã sao chép vào khay nhớ tạm",
        ),
      ));
    });
  }

  Future logFA(String name, {Map<String, dynamic>? params}) =>
      FirebaseAnalyticsService().logEvent(name, params ?? {});

  bool get isAuthenticated => authCubit.state.isAuthenticated;
  FireStoreService get fireStoreService => FireStoreService();
}
