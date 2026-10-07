import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';

/// Dumb Widget hiển thị các nút hành động (Mở cài đặt / Thử lại) khi có lỗi nhận diện giọng nói.
///
/// Thuần StatelessWidget, bắn sự kiện qua callback; không phụ thuộc BLoC.
class VoiceSearchActionButtons extends StatelessWidget {
  final bool isPermissionDenied;
  final bool isError;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onRetry;

  const VoiceSearchActionButtons({
    super.key,
    this.isPermissionDenied = false,
    this.isError = false,
    this.onOpenSettings,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    if (isPermissionDenied && onOpenSettings != null) {
      return AppButton.primary(
        text: tr(LocaleKeys.search_bar_voice_open_settings),
        icon: const Icon(Icons.settings_rounded, size: 18),
        width: null,
        height: 44,
        borderRadius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        onPressed: onOpenSettings,
      );
    }

    if (isError && onRetry != null) {
      return AppButton.outlined(
        text: tr(LocaleKeys.search_bar_voice_try_again),
        icon: const Icon(Icons.refresh_rounded, size: 18),
        width: null,
        height: 44,
        borderRadius: 14,
        textColor: colorScheme.primary,
        borderColor: colorScheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        onPressed: onRetry,
      );
    }

    return const SizedBox.shrink();
  }
}
