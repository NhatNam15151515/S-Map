import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/generated/locale_keys.g.dart';

/// Dumb Widget hiển thị dòng trạng thái / lời nhắc hoặc khung transcript văn bản nhận diện.
///
/// Thuần StatelessWidget nhận dữ liệu qua props, không phụ thuộc BLoC.
class VoiceSearchStatusView extends StatelessWidget {
  final bool isListening;
  final bool isSuccess;
  final bool isError;
  final bool isPermissionDenied;
  final bool isUnavailable;
  final String recognizedText;

  const VoiceSearchStatusView({
    super.key,
    this.isListening = false,
    this.isSuccess = false,
    this.isError = false,
    this.isPermissionDenied = false,
    this.isUnavailable = false,
    this.recognizedText = '',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final text = recognizedText.trim();

    // 1. Nếu đã có transcript (đang nghe hoặc thành công)
    if (text.isNotEmpty) {
      final boxColor = isSuccess
          ? colorScheme.primary.withValues(alpha: 0.15)
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
      final textColor =
          isSuccess ? colorScheme.primary : colorScheme.onSurface;

      return Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: boxColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          '"$text"',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: AppFontWeight.bold.weight,
            color: textColor,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    // 2. Đang lắng nghe âm thanh từ người dùng
    if (isListening) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tr(LocaleKeys.search_bar_voice_listening),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: AppFontWeight.bold.weight,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr(LocaleKeys.search_bar_voice_hint),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    // 3. Quyền microphone bị từ chối
    if (isPermissionDenied) {
      return Text(
        tr(LocaleKeys.search_bar_voice_permission_denied),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.error,
        ),
        textAlign: TextAlign.center,
      );
    }

    // 4. Máy không hỗ trợ hoặc dịch vụ không khả dụng
    if (isUnavailable) {
      return Text(
        tr(LocaleKeys.search_bar_voice_unavailable),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.error,
        ),
        textAlign: TextAlign.center,
      );
    }

    // 5. Gặp lỗi trong quá trình nhận diện
    if (isError) {
      return Text(
        tr(LocaleKeys.search_bar_voice_try_again),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.error,
        ),
        textAlign: TextAlign.center,
      );
    }

    // 6. Trạng thái khởi tạo / mặc định
    return Text(
      tr(LocaleKeys.search_bar_voice_hint),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      textAlign: TextAlign.center,
    );
  }
}
