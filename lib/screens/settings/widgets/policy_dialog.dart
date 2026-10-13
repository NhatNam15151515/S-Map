import 'package:flutter/material.dart';
import 'package:s_map/commons/widgets/widgets.dart';

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
    return AppInfoDialog.show(
      context,
      title: title,
      message: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppInfoDialog(
      title: title,
      message: content,
    );
  }
}
