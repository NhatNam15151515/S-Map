import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class PolicyDialog extends StatelessWidget {
  final String title;
  final String content;

  const PolicyDialog({
    super.key,
    required this.title,
    required this.content,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => PolicyDialog(
        title: title,
        content: content,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        title,
        style: colorScheme.onSurface.textTheme.boldStyle.copyWith(
          fontSize: 18,
        ),
      ),
      content: SingleChildScrollView(
        child: Text(
          content,
          style: colorScheme.onSurface.textTheme.textStyle.copyWith(
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => context.safePop(),
          child: Text(
            tr(LocaleKeys.close),
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
