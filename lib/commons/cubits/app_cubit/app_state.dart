import 'package:equatable/equatable.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/localizations/app_localization.dart';

enum AppStateType { initial, loaded }

class AppState extends Equatable {
  final AppStyle appStyle;
  final SupportedLocale supportedLocale;
  final AppStateType type;

  const AppState({
    required this.appStyle,
    required this.supportedLocale,
    required this.type,
  });

  SupportedLocale get dLocale => SupportedLocale.vi;

  AppState copyWith({
    AppStyle? appStyle,
    SupportedLocale? supportedLocale,
    AppStateType? type,
  }) {
    return AppState(
      type: type ?? this.type,
      appStyle: appStyle ?? this.appStyle,
      supportedLocale: supportedLocale ?? this.supportedLocale,
    );
  }

  @override
  List<Object?> get props => [appStyle, supportedLocale, type];
}

