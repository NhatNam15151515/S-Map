import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class UserProfileCard extends StatelessWidget {
  final String? username;
  final String appName;
  final VoidCallback? onViewProfile;

  const UserProfileCard({
    super.key,
    this.username,
    required this.appName,
    this.onViewProfile,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = (username != null && username!.trim().isNotEmpty)
        ? username!.trim()
        : tr(
            LocaleKeys.default_user_name,
            args: [appName],
          );

    final colorScheme = context.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outline.withAlpha(50),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const ProfileAvatar(size: 72, borderWidth: 2.5),
          const SizedBox(height: 16),
          Text(
            displayName,
            style: colorScheme.onSurface.textTheme.subTitleStyle.copyWith(
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: onViewProfile,
            child: Text(
              tr(LocaleKeys.viewProfile),
              style: colorScheme.primary.textTheme.boldStyle.copyWith(
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
