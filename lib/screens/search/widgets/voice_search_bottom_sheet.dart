import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:s_map/commons/blocs/voice_search_bloc/voice_search_bloc.dart';
import 'package:s_map/commons/blocs/voice_search_bloc/voice_search_event.dart';
import 'package:s_map/commons/blocs/voice_search_bloc/voice_search_state.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/popups/app_bottom_sheet_util.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/interfaces/i_speech_recognition_service.dart';

import 'voice_mic_visualizer.dart';
import 'voice_search_action_buttons.dart';
import 'voice_search_status_view.dart';

/// Modal Bottom Sheet nhận diện giọng nói cho tính năng Voice Search.
///
/// Tận dụng [AppBottomSheetUtil.bottomSheetContainer] chuẩn của app
/// và phối hợp các dumb widgets chuyên trách để hiển thị giao diện.
Future<String?> showVoiceSearchBottomSheet(
  BuildContext context, {
  ISpeechRecognitionService? speechService,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (modalContext) => VoiceSearchBottomSheet(
      speechService: speechService,
    ),
  );
}

class VoiceSearchBottomSheet extends StatelessWidget {
  final ISpeechRecognitionService? speechService;

  const VoiceSearchBottomSheet({
    super.key,
    this.speechService,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<VoiceSearchBloc>(
      create: (ctx) => VoiceSearchBloc(speechService: speechService)
        ..add(const VoiceSearchStarted(localeId: 'vi_VN')),
      child: const _VoiceSearchView(),
    );
  }
}

class _VoiceSearchView extends StatefulWidget {
  const _VoiceSearchView();

  @override
  State<_VoiceSearchView> createState() => _VoiceSearchViewState();
}

class _VoiceSearchViewState extends State<_VoiceSearchView> {
  Timer? _autoDismissTimer;

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  void _onSuccessResult(String text) {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        Navigator.of(context).pop(text);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final styles = AppStyle.of(context);

    return AppBottomSheetUtil.bottomSheetContainer(
      tr(LocaleKeys.search_bar_voice),
      styles,
      context,
      BlocConsumer<VoiceSearchBloc, VoiceSearchState>(
        listenWhen: (previous, current) =>
            previous.status != current.status && current.isSuccess,
        listener: (context, state) {
          if (state.recognizedText.trim().isNotEmpty) {
            _onSuccessResult(state.recognizedText.trim());
          }
        },
        builder: (context, state) {
          final isErrorState =
              state.isError || state.isPermissionDenied || state.isUnavailable;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dumb widget: Vòng sóng âm & nút mic
                VoiceMicVisualizer(
                  isListening: state.isListening,
                  isSuccess: state.isSuccess,
                  isError: isErrorState,
                  soundLevel: state.soundLevel,
                  onTap: () {
                    final bloc = context.read<VoiceSearchBloc>();
                    if (state.isListening) {
                      bloc.add(const VoiceSearchStopped());
                    } else {
                      bloc.add(const VoiceSearchStarted(localeId: 'vi_VN'));
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Dumb widget: Dòng thông báo / hộp kết quả nhận diện
                VoiceSearchStatusView(
                  isListening: state.isListening,
                  isSuccess: state.isSuccess,
                  isError: state.isError,
                  isPermissionDenied: state.isPermissionDenied,
                  isUnavailable: state.isUnavailable,
                  recognizedText: state.recognizedText,
                ),
                const SizedBox(height: 16),

                // Dumb widget: Nút Thử lại / Cài đặt khi có lỗi
                VoiceSearchActionButtons(
                  isPermissionDenied: state.isPermissionDenied,
                  isError: state.isError,
                  onOpenSettings: openAppSettings,
                  onRetry: () => context
                      .read<VoiceSearchBloc>()
                      .add(const VoiceSearchStarted(localeId: 'vi_VN')),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
