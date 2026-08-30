import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class ThemeModeDialog extends StatelessWidget {
  final ThemeMode currentMode;

  const ThemeModeDialog({super.key, required this.currentMode});

  static Future<void> show(BuildContext context, ThemeMode currentMode) {
    return showDialog<void>(
      context: context,
      builder: (_) => ThemeModeDialog(currentMode: currentMode),
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
        tr(LocaleKeys.themeMode),
        style: style.blackTextColor.textTheme.boldStyle.copyWith(
          fontSize: 18,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOptionTile(
            context: context,
            title: tr(LocaleKeys.themeModeSystem),
            value: ThemeMode.system,
            groupValue: currentMode,
            style: style,
          ),
          const SizedBox(height: 4),
          _buildOptionTile(
            context: context,
            title: tr(LocaleKeys.themeModeLight),
            value: ThemeMode.light,
            groupValue: currentMode,
            style: style,
          ),
          const SizedBox(height: 4),
          _buildOptionTile(
            context: context,
            title: tr(LocaleKeys.themeModeDark),
            value: ThemeMode.dark,
            groupValue: currentMode,
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
    required ThemeMode value,
    required ThemeMode groupValue,
    required AppStyle style,
  }) {
    final isSelected = value == groupValue;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('theme_option_${value.name}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          context.read<AppCubit>().onChangeThemeMode(value);
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
