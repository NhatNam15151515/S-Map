import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/routers/app_routes.dart';
import 'package:s_map/screens/main/user/widgets/widgets.dart';

class UserScreen extends StatelessWidget with AppMixin, AuthMixin {
  const UserScreen({super.key});

  void _shareLocation(BuildContext context) {
    final mapCubit = context.read<MapDisplayCubit>();
    final pos = mapCubit.state.currentPosition;
    final message = pos != null
        ? tr(
            LocaleKeys.user_share_location_message,
            args: ['https://maps.google.com/?q=${pos.latitude},${pos.longitude}'],
          )
        : tr(LocaleKeys.user_share_location_fallback);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _processAndSaveAvatar(
    BuildContext context,
    Uint8List rawBytes,
  ) async {
    try {
      final base64String = await AvatarUtils.compressToBase64(rawBytes);

      if (!context.mounted) return;
      final authCubit = context.read<AuthCubit>();
      final messenger = ScaffoldMessenger.of(context);
      final themeColors = context.themeColors;

      await authCubit.updateAvatarBase64(base64String);

      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: themeColors.statsSuccess,
          content: Text(tr(LocaleKeys.user_update_avatar_success)),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: colorScheme.error,
            content: Text(
              tr(LocaleKeys.user_process_avatar_error, args: ['$e']),
            ),
          ),
        );
      }
    }
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (context.mounted) {
          await _processAndSaveAvatar(context, bytes);
        }
      }
    } catch (e) {
      if (context.mounted) {
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: colorScheme.error,
            content: Text(
              source == ImageSource.camera
                  ? tr(LocaleKeys.user_open_camera_error, args: ['$e'])
                  : tr(LocaleKeys.user_pick_gallery_error, args: ['$e']),
            ),
          ),
        );
      }
    }
  }

  void _showAvatarOptionsSheet(BuildContext context, User profile) {
    final hasAvatar = profile.avatarBase64 != null &&
        profile.avatarBase64!.trim().isNotEmpty;

    UserAvatarOptionsSheet.show(
      context,
      hasAvatar: hasAvatar,
      onViewAvatar: () {
        UserAvatarPreviewDialog.show(context, profile.avatarBase64!);
      },
      onTakePhoto: () => _pickImage(context, ImageSource.camera),
      onPickGallery: () => _pickImage(context, ImageSource.gallery),
      onDeleteAvatar: () async {
        await context.read<AuthCubit>().updateAvatarBase64('');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr(LocaleKeys.user_delete_avatar_success)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.select<AuthCubit, bool>(
      (c) => c.state.isAuthenticated,
    );
    final userProfile = context.select<AuthCubit, User>(
      (c) => c.currentProfile,
    );

    return Scaffold(
      appBar: TitleAppBar(
        title: tr(LocaleKeys.profile),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: marginBottomDefault),
        child: Column(
          children: [
            // 1. Profile header card
            UserProfileCard(
              username: userProfile.username,
              avatarBase64: userProfile.avatarBase64,
              appName: appName,
              onViewProfile: () =>
                  UserProfileDetailDialog.show(context, userProfile),
              onAvatarTap: () => _showAvatarOptionsSheet(context, userProfile),
            ),

            // 2. Navigation menu items
            UserMenuCard(
              children: [
                UserMenuTile(
                  icon: Icons.bookmark_rounded,
                  title: tr(LocaleKeys.savedPlaces),
                  onTap: () => context.go(AppRoutes.saved),
                ),
                UserMenuTile(
                  icon: Icons.history_rounded,
                  title: tr(LocaleKeys.activityHistory),
                  onTap: () => context.go(AppRoutes.stats),
                ),
                UserMenuTile(
                  icon: Icons.share_rounded,
                  title: tr(LocaleKeys.shareLocation),
                  onTap: () => _shareLocation(context),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 3. Settings and About
            UserMenuCard(
              children: [
                UserMenuTile(
                  icon: Icons.settings_rounded,
                  title: tr(LocaleKeys.settings),
                  onTap: () => context.push(AppRoutes.settings),
                ),
                UserMenuTile(
                  icon: Icons.help_outline_rounded,
                  title: tr(LocaleKeys.helpAndFeedback),
                  onTap: () => HelpFeedbackDialog.show(context),
                ),
                UserMenuTile(
                  icon: Icons.info_outline_rounded,
                  title: tr(LocaleKeys.about),
                  onTap: () => context.push(AppRoutes.settings),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 4. Auth action (Login if unauthenticated, Logout if authenticated)
            UserMenuCard(
              children: [
                if (isAuthenticated)
                  UserMenuTile(
                    icon: Icons.logout_rounded,
                    title: tr(LocaleKeys.logOut),
                    onTap: () => authCubit.onLogout(),
                    isDestructive: true,
                  )
                else
                  UserMenuTile(
                    icon: Icons.login_rounded,
                    title: tr(LocaleKeys.login),
                    onTap: () => context.push(AppRoutes.login),
                    isDestructive: false,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
