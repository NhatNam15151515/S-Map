import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/rxdart.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/styles/themes/dark_theme.dart';
import 'package:s_map/commons/styles/themes/default_theme.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/localizations/app_localization.dart';
import 'package:s_map/models/models.dart';

class MockFirebaseMessagingService implements IFirebaseMessagingService {
  @override
  Completer<bool> fmsCompleter = Completer<bool>();

  bool onAppStartedCalled = false;

  @override
  BehaviorSubject<NotificationModel?> comingNotificationListener =
      BehaviorSubject<NotificationModel?>.seeded(null);

  @override
  Future<void> init() async {}

  @override
  Future<String?> getToken() async => 'mock_token';

  @override
  Future<void> onClickNotification(
    NotificationModel notificationModel, {
    bool openFromBanner = false,
  }) async {}

  @override
  Future<void> onAppStartedWithNotification() async {
    onAppStartedCalled = true;
  }
}

class FakeSharedPreferences implements ISharedPreferences {
  String? storedTheme;
  bool isFirst = false;

  @override
  Future<bool> get1stInstall() async => isFirst;

  @override
  Future<void> save1stInstall() async => isFirst = false;

  @override
  Future<String?> getThemeMode() async => storedTheme;

  @override
  Future<void> saveThemeMode(String mode) async {
    storedTheme = mode;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppCubit Tests - onMainScreenMounted', () {
    test('onMainScreenMounted completes fmsCompleter and calls onAppStartedWithNotification', () {
      final mockMessaging = MockFirebaseMessagingService();
      final appCubit = AppCubit();

      expect(mockMessaging.fmsCompleter.isCompleted, isFalse);
      expect(mockMessaging.onAppStartedCalled, isFalse);

      appCubit.onMainScreenMounted(messagingService: mockMessaging);

      expect(mockMessaging.fmsCompleter.isCompleted, isTrue);
      expect(mockMessaging.onAppStartedCalled, isTrue);

      appCubit.close();
    });
  });

  group('AppCubit Tests - ThemeMode & Dark Theme', () {
    test('initial state has ThemeMode.system and DefaultTheme by default', () {
      final fakePrefs = FakeSharedPreferences();
      final appCubit = AppCubit(sharedPreferences: fakePrefs);

      expect(appCubit.state.themeMode, equals(ThemeMode.system));
      expect(appCubit.state.appStyle, isA<DefaultTheme>());
      expect(appCubit.state.isDarkMode, isFalse);

      appCubit.close();
    });

    test('onChangeThemeMode sets DarkTheme on dark and saves to prefs', () {
      final fakePrefs = FakeSharedPreferences();
      final appCubit = AppCubit(sharedPreferences: fakePrefs);

      appCubit.onChangeThemeMode(ThemeMode.dark);

      expect(appCubit.state.themeMode, equals(ThemeMode.dark));
      expect(appCubit.state.appStyle, isA<DarkTheme>());
      expect(appCubit.state.isDarkMode, isTrue);
      expect(fakePrefs.storedTheme, equals('dark'));

      appCubit.onChangeThemeMode(ThemeMode.light);

      expect(appCubit.state.themeMode, equals(ThemeMode.light));
      expect(appCubit.state.appStyle, isA<DefaultTheme>());
      expect(appCubit.state.isDarkMode, isFalse);
      expect(fakePrefs.storedTheme, equals('light'));

      appCubit.close();
    });

    test('toggleDarkMode toggles between dark and light', () {
      final fakePrefs = FakeSharedPreferences();
      final appCubit = AppCubit(sharedPreferences: fakePrefs);

      appCubit.toggleDarkMode(true);
      expect(appCubit.state.themeMode, equals(ThemeMode.dark));
      expect(appCubit.state.isDarkMode, isTrue);

      appCubit.toggleDarkMode(false);
      expect(appCubit.state.themeMode, equals(ThemeMode.light));
      expect(appCubit.state.isDarkMode, isFalse);

      appCubit.close();
    });

    test('initTheme restores dark mode from preferences', () async {
      final fakePrefs = FakeSharedPreferences()..storedTheme = 'dark';
      final appCubit = AppCubit(sharedPreferences: fakePrefs);

      await appCubit.initTheme();

      expect(appCubit.state.themeMode, equals(ThemeMode.dark));
      expect(appCubit.state.appStyle, isA<DarkTheme>());
      expect(appCubit.state.isDarkMode, isTrue);

      appCubit.close();
    });

    test('onChangeLocale updates locale state', () {
      final appCubit = AppCubit();
      expect(appCubit.state.supportedLocale, equals(SupportedLocale.vi));

      appCubit.onChangeLocale(SupportedLocale.en);
      expect(appCubit.state.supportedLocale, equals(SupportedLocale.en));

      appCubit.close();
    });
  });
}
