import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/localizations/app_localization.dart';

class LanguageDialog extends StatelessWidget {
  final SupportedLocale currentLocale;

  const LanguageDialog({super.key, required this.currentLocale});

  static List<AppRadioOption<SupportedLocale>> _buildOptions() {
    return const [
      AppRadioOption(
        key: ValueKey('lang_option_vi'),
        value: SupportedLocale.vi,
        title: 'Tiếng Việt',
      ),
      AppRadioOption(
        key: ValueKey('lang_option_en'),
        value: SupportedLocale.en,
        title: 'English',
      ),
    ];
  }

  static Future<void> show(BuildContext context, SupportedLocale currentLocale) {
    return AppRadioSelectDialog.show<SupportedLocale>(
      context: context,
      title: tr(LocaleKeys.language),
      selectedValue: currentLocale,
      options: _buildOptions(),
      onSelected: (locale) {
        context.read<AppCubit>().onChangeLocale(locale, context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppRadioSelectDialog<SupportedLocale>(
      title: tr(LocaleKeys.language),
      selectedValue: currentLocale,
      options: _buildOptions(),
      onSelected: (locale) {
        context.read<AppCubit>().onChangeLocale(locale, context);
      },
    );
  }
}
