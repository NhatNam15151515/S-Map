import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/screens/main/user/widgets/user_avatar_preview_dialog.dart';

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
    final hasAvatar = profile.avatarBase64 != null &&
        profile.avatarBase64!.trim().isNotEmpty;

    return AppInfoDialog(
      icon: Icons.account_circle_rounded,
      title: tr(LocaleKeys.profile),
      actionLabel: 'Đóng',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ProfileAvatar(
                size: 64,
                borderWidth: 2,
                avatarBase64: profile.avatarBase64,
                onTap: hasAvatar
                    ? () => UserAvatarPreviewDialog.show(
                          context,
                          profile.avatarBase64!,
                        )
                    : null,
              ),
            ),
          ),
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
          if (profile.id != null) ...[
            Text(
              'ID: ${profile.id}',
              style: colorScheme.onSurfaceVariant.textTheme.textStyle,
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}
