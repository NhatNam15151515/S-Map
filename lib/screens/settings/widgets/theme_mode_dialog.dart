import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class ThemeModeDialog extends StatelessWidget {
  final ThemeMode currentMode;

  const ThemeModeDialog({super.key, required this.currentMode});

  static List<AppRadioOption<ThemeMode>> _buildOptions() {
    return [
      AppRadioOption(
        key: const ValueKey('theme_option_system'),
        value: ThemeMode.system,
        title: tr(LocaleKeys.themeModeSystem),
      ),
      AppRadioOption(
        key: const ValueKey('theme_option_light'),
        value: ThemeMode.light,
        title: tr(LocaleKeys.themeModeLight),
      ),
      AppRadioOption(
        key: const ValueKey('theme_option_dark'),
        value: ThemeMode.dark,
        title: tr(LocaleKeys.themeModeDark),
      ),
    ];
  }

  static Future<void> show(BuildContext context, ThemeMode currentMode) {
    return AppRadioSelectDialog.show<ThemeMode>(
      context: context,
      title: tr(LocaleKeys.themeMode),
      selectedValue: currentMode,
      options: _buildOptions(),
      onSelected: (mode) {
        context.read<AppCubit>().onChangeThemeMode(mode);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppRadioSelectDialog<ThemeMode>(
      title: tr(LocaleKeys.themeMode),
      selectedValue: currentMode,
      options: _buildOptions(),
      onSelected: (mode) {
        context.read<AppCubit>().onChangeThemeMode(mode);
      },
    );
  }
}
