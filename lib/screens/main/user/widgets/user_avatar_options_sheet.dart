import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';

/// Pure Dumb Widget hiển thị modal sheet các tùy chọn cho ảnh đại diện (xem, chụp, chọn, xóa).
///
/// Sử dụng cấu trúc danh sách nhóm [AppSettingGroup] và [AppSettingTile] đồng nhất với hệ thống cài đặt.
class UserAvatarOptionsSheet extends StatelessWidget {
  final bool hasAvatar;
  final VoidCallback? onViewAvatar;
  final VoidCallback? onTakePhoto;
  final VoidCallback? onPickGallery;
  final VoidCallback? onDeleteAvatar;

  const UserAvatarOptionsSheet({
    super.key,
    required this.hasAvatar,
    this.onViewAvatar,
    this.onTakePhoto,
    this.onPickGallery,
    this.onDeleteAvatar,
  });

  /// Hiển thị bottom sheet tùy chọn ảnh đại diện.
  static Future<void> show(
    BuildContext context, {
    required bool hasAvatar,
    VoidCallback? onViewAvatar,
    VoidCallback? onTakePhoto,
    VoidCallback? onPickGallery,
    VoidCallback? onDeleteAvatar,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => UserAvatarOptionsSheet(
        hasAvatar: hasAvatar,
        onViewAvatar: onViewAvatar,
        onTakePhoto: onTakePhoto,
        onPickGallery: onPickGallery,
        onDeleteAvatar: onDeleteAvatar,
      ),
    );
  }

  void _popAndCall(BuildContext context, VoidCallback? callback) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    callback?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outline.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                tr(LocaleKeys.user_avatar_title),
                style: colorScheme.onSurface.textTheme.boldStyle.copyWith(
                  fontSize: 18,
                ),
              ),
            ),
            AppSettingGroup(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              hasBorder: true,
              children: [
                if (hasAvatar && onViewAvatar != null)
                  AppSettingTile(
                    key: const Key('avatar_option_view'),
                    icon: Icons.visibility_outlined,
                    title: tr(LocaleKeys.user_avatar_view),
                    subtitle: tr(LocaleKeys.user_avatar_view_desc),
                    showChevron: false,
                    onTap: () => _popAndCall(context, onViewAvatar),
                  ),
                if (onTakePhoto != null)
                  AppSettingTile(
                    key: const Key('avatar_option_camera'),
                    icon: Icons.camera_alt_outlined,
                    title: tr(LocaleKeys.user_avatar_take_photo),
                    subtitle: tr(LocaleKeys.user_avatar_take_photo_desc),
                    showChevron: false,
                    onTap: () => _popAndCall(context, onTakePhoto),
                  ),
                if (onPickGallery != null)
                  AppSettingTile(
                    key: const Key('avatar_option_gallery'),
                    icon: Icons.photo_library_outlined,
                    title: tr(LocaleKeys.user_avatar_pick_gallery),
                    subtitle: tr(LocaleKeys.user_avatar_pick_gallery_desc),
                    showChevron: false,
                    onTap: () => _popAndCall(context, onPickGallery),
                  ),
                if (hasAvatar && onDeleteAvatar != null)
                  AppSettingTile(
                    key: const Key('avatar_option_delete'),
                    icon: Icons.delete_outline_rounded,
                    title: tr(LocaleKeys.user_avatar_delete),
                    subtitle: tr(LocaleKeys.user_avatar_delete_desc),
                    isDestructive: true,
                    showChevron: false,
                    onTap: () => _popAndCall(context, onDeleteAvatar),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
