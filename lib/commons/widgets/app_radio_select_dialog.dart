import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class AppRadioOption<T> {
  final T value;
  final String title;
  final Key? key;

  const AppRadioOption({
    required this.value,
    required this.title,
    this.key,
  });
}

class AppRadioSelectDialog<T> extends StatelessWidget {
  final String title;
  final T selectedValue;
  final List<AppRadioOption<T>> options;
  final ValueChanged<T> onSelected;

  const AppRadioSelectDialog({
    super.key,
    required this.title,
    required this.selectedValue,
    required this.options,
    required this.onSelected,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required T selectedValue,
    required List<AppRadioOption<T>> options,
    required ValueChanged<T> onSelected,
  }) {
    return showDialog<T>(
      context: context,
      builder: (_) => AppRadioSelectDialog<T>(
        title: title,
        selectedValue: selectedValue,
        options: options,
        onSelected: onSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);
    final colorScheme = style.colorScheme;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        title,
        style: style.blackTextColor.textTheme.boldStyle.copyWith(
          fontSize: 18,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: options.map((option) {
          final isSelected = option.value == selectedValue;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: option.key,
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  onSelected(option.value);
                  context.safePop();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                        size: 22,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          option.title,
                          style: colorScheme.onSurface.textTheme.textStyle
                              .copyWith(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => context.safePop(),
          child: Text(
            tr(LocaleKeys.cancel),
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
