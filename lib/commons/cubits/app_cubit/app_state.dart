import 'package:equatable/equatable.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/localizations/app_localization.dart';

enum AppStateType { initial, loaded }

class AppState extends Equatable {
  final AppStyle appStyle;
  final SupportedLocale supportedLocale;
  final AppStateType type;
  final String appName;

  const AppState({
    required this.appStyle,
    required this.supportedLocale,
    required this.type,
    required this.appName,
  });

  SupportedLocale get dLocale => SupportedLocale.vi;

  AppState copyWith({
    AppStyle? appStyle,
    SupportedLocale? supportedLocale,
    AppStateType? type,
    String? appName,
  }) {
    return AppState(
      type: type ?? this.type,
      appStyle: appStyle ?? this.appStyle,
      supportedLocale: supportedLocale ?? this.supportedLocale,
      appName: appName ?? this.appName,
    );
  }

  @override
  List<Object?> get props => [appStyle, supportedLocale, type, appName];
}
