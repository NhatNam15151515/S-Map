import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/i_speech_recognition_service.dart';
import 'package:s_map/services/speech_recognition_service.dart';
import 'voice_search_event.dart';
import 'voice_search_state.dart';

/// BLoC quản lý trạng thái nhận diện giọng nói cho tính năng Voice Search.
/// 
/// Độc lập hoàn toàn với [SearchBloc] để tuân thủ Single Responsibility Principle.
/// Kết quả nhận diện thành công sẽ được trả về cho UI gọi vào SearchBloc.
class VoiceSearchBloc extends Bloc<VoiceSearchEvent, VoiceSearchState> {
  final ISpeechRecognitionService _speechService;

  VoiceSearchBloc({
    ISpeechRecognitionService? speechService,
  })  : _speechService = speechService ?? SpeechRecognitionService(),
        super(const VoiceSearchState()) {
    on<VoiceSearchStarted>(_onStarted);
    on<VoiceSearchStopped>(_onStopped);
    on<VoiceSearchCancelled>(_onCancelled);
    on<VoiceSearchResultReceived>(_onResultReceived);
    on<VoiceSearchSoundLevelChanged>(_onSoundLevelChanged);
    on<VoiceSearchErrorOccurred>(_onErrorOccurred);
  }

  Future<void> _onStarted(
    VoiceSearchStarted event,
    Emitter<VoiceSearchState> emit,
  ) async {
    emit(state.copyWith(
      status: VoiceSearchStatus.initializing,
      recognizedText: '',
      soundLevel: 0.0,
      isFinal: false,
    ));

    // 1. Kiểm tra & xin quyền Microphone
    try {
      final micPermission = await Permission.microphone.status;
      if (micPermission.isPermanentlyDenied) {
        emit(state.copyWith(
          status: VoiceSearchStatus.permissionDenied,
          errorMessage: 'Microphone permission permanently denied',
        ));
        return;
      }

      if (!micPermission.isGranted) {
        final requestResult = await Permission.microphone.request();
        if (!requestResult.isGranted) {
          emit(state.copyWith(
            status: VoiceSearchStatus.permissionDenied,
            errorMessage: 'Microphone permission denied',
          ));
          return;
        }
      }
    } catch (e) {
      DLog.warning('VoiceSearchBloc permission check warning: $e');
      // Tiếp tục thử khởi tạo STT SDK vì SDK cũng có native permission fallback
    }

    // 2. Khởi tạo engine
    final isAvailable = await _speechService.initialize();
    if (!isAvailable) {
      emit(state.copyWith(
        status: VoiceSearchStatus.unavailable,
        errorMessage: 'Speech recognition is not available',
      ));
      return;
    }

    emit(state.copyWith(
      status: VoiceSearchStatus.listening,
      recognizedText: '',
      soundLevel: 0.0,
    ));

    // 3. Bắt đầu lắng nghe
    await _speechService.startListening(
      localeId: event.localeId,
      onResult: (text, isFinal) {
        add(VoiceSearchResultReceived(text, isFinal: isFinal));
      },
      onSoundLevel: (level) {
        // Chuẩn hóa mức âm thanh từ dB (-10 -> 10) về khoảng [0.0, 1.0]
        final normalized = ((level + 10) / 20).clamp(0.0, 1.0);
        add(VoiceSearchSoundLevelChanged(normalized));
      },
      onError: (error) {
        add(VoiceSearchErrorOccurred(error));
      },
    );
  }

  Future<void> _onStopped(
    VoiceSearchStopped event,
    Emitter<VoiceSearchState> emit,
  ) async {
    await _speechService.stopListening();
    if (state.recognizedText.trim().isNotEmpty) {
      emit(state.copyWith(
        status: VoiceSearchStatus.success,
        isFinal: true,
      ));
    } else {
      emit(state.copyWith(
        status: VoiceSearchStatus.error,
        errorMessage: 'No speech recognized',
      ));
    }
  }

  Future<void> _onCancelled(
    VoiceSearchCancelled event,
    Emitter<VoiceSearchState> emit,
  ) async {
    await _speechService.cancelListening();
    emit(const VoiceSearchState(status: VoiceSearchStatus.initial));
  }

  void _onResultReceived(
    VoiceSearchResultReceived event,
    Emitter<VoiceSearchState> emit,
  ) {
    if (event.isFinal) {
      emit(state.copyWith(
        status: VoiceSearchStatus.success,
        recognizedText: event.recognizedText,
        isFinal: true,
      ));
    } else {
      emit(state.copyWith(
        status: VoiceSearchStatus.listening,
        recognizedText: event.recognizedText,
        isFinal: false,
      ));
    }
  }

  void _onSoundLevelChanged(
    VoiceSearchSoundLevelChanged event,
    Emitter<VoiceSearchState> emit,
  ) {
    if (state.isListening) {
      emit(state.copyWith(soundLevel: event.soundLevel));
    }
  }

  void _onErrorOccurred(
    VoiceSearchErrorOccurred event,
    Emitter<VoiceSearchState> emit,
  ) {
    // Nếu trước đó đã kịp nhận diện được text, xem như kết thúc thành công
    if (state.recognizedText.trim().isNotEmpty) {
      emit(state.copyWith(
        status: VoiceSearchStatus.success,
        isFinal: true,
      ));
    } else {
      emit(state.copyWith(
        status: VoiceSearchStatus.error,
        errorMessage: event.errorMessage,
      ));
    }
  }

  @override
  Future<void> close() {
    _speechService.dispose();
    return super.close();
  }
}
