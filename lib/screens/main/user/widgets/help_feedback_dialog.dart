import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/widgets/widgets.dart';
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
    return AppInfoDialog(
      icon: Icons.help_outline_rounded,
      title: tr(LocaleKeys.helpAndFeedback),
      actionLabel: tr(LocaleKeys.close),
      message: tr(LocaleKeys.help_feedback_content),
    );
  }
}

