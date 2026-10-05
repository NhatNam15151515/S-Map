import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class LoginDividerWidget extends StatelessWidget {
  const LoginDividerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: colorScheme.outline.withAlpha(150),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            tr(LocaleKeys.or),
            style: colorScheme.onSurfaceVariant.textTheme.captionStyle.copyWith(
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: colorScheme.outline.withAlpha(150),
          ),
        ),
      ],
    );
  }
}
