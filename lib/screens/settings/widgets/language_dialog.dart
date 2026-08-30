import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/localizations/app_localization.dart';

class LanguageDialog extends StatelessWidget {
  final SupportedLocale currentLocale;

  const LanguageDialog({super.key, required this.currentLocale});

  static Future<void> show(BuildContext context, SupportedLocale currentLocale) {
    return showDialog<void>(
      context: context,
      builder: (_) => LanguageDialog(currentLocale: currentLocale),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);

    return AlertDialog(
      backgroundColor: style.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        tr(LocaleKeys.language),
        style: style.blackTextColor.textTheme.boldStyle.copyWith(
          fontSize: 18,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOptionTile(
            context: context,
            title: 'Tiếng Việt',
            value: SupportedLocale.vi,
            groupValue: currentLocale,
            style: style,
          ),
          const SizedBox(height: 4),
          _buildOptionTile(
            context: context,
            title: 'English',
            value: SupportedLocale.en,
            groupValue: currentLocale,
            style: style,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => context.safePop(),
          child: Text(
            tr(LocaleKeys.cancel),
            style: TextStyle(
              color: style.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required BuildContext context,
    required String title,
    required SupportedLocale value,
    required SupportedLocale groupValue,
    required AppStyle style,
  }) {
    final isSelected = value == groupValue;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('lang_option_${value.name}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          context.read<AppCubit>().onChangeLocale(value, context);
          context.safePop();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected
                    ? context.colorScheme.primary
                    : context.colorScheme.onSurfaceVariant,
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: context.colorScheme.onSurface.textTheme.textStyle.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
