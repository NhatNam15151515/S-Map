import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class HelpFeedbackDialog extends StatelessWidget {
  const HelpFeedbackDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const HelpFeedbackDialog(),
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
      title: Row(
        children: [
          Icon(
            Icons.help_outline_rounded,
            color: colorScheme.primary,
            size: 28,
          ),
          const SizedBox(width: 10),
          Text(
            tr(LocaleKeys.helpAndFeedback),
            style: colorScheme.onSurface.textTheme.boldStyle.copyWith(
              fontSize: 18,
            ),
          ),
        ],
      ),
      content: Text(
        'Mọi thắc mắc hoặc đóng góp ý kiến về tính năng bản đồ và dẫn đường, vui lòng liên hệ đội ngũ phát triển S-Map.',
        style: colorScheme.onSurface.textTheme.textStyle.copyWith(
          fontSize: 14,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => context.safePop(),
          child: Text(
            'Đóng',
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
