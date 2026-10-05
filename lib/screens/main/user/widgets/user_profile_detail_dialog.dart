import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';

class UserProfileDetailDialog extends StatelessWidget {
  final User profile;

  const UserProfileDetailDialog({super.key, required this.profile});

  static Future<void> show(BuildContext context, User profile) {
    return showDialog<void>(
      context: context,
      builder: (_) => UserProfileDetailDialog(profile: profile),
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
            Icons.account_circle_rounded,
            color: colorScheme.primary,
            size: 28,
          ),
          const SizedBox(width: 10),
          Text(
            tr(LocaleKeys.profile),
            style: colorScheme.onSurface.textTheme.boldStyle.copyWith(
              fontSize: 18,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tên: ${profile.username ?? "Khách"}',
            style: colorScheme.onSurface.textTheme.textStyle.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (profile.email != null && profile.email!.isNotEmpty) ...[
            Text(
              'Email: ${profile.email}',
              style: colorScheme.onSurfaceVariant.textTheme.textStyle,
            ),
            const SizedBox(height: 4),
          ],
          if (profile.id != null)
            Text(
              'ID: ${profile.id}',
              style: colorScheme.onSurfaceVariant.textTheme.textStyle,
            ),
        ],
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
