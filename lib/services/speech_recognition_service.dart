import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/i_speech_recognition_service.dart';

/// Dịch vụ nhận diện giọng nói (Speech-to-Text).
///
/// Đóng gói SDK [stt.SpeechToText] để cung cấp API sạch sẽ,
/// hỗ trợ tự động tìm locale tiếng Việt (`vi_VN`), stream mức âm lượng (dB)
/// và kết quả nhận diện tạm thời / kết quả cuối cùng.
class SpeechRecognitionService implements ISpeechRecognitionService {
  final stt.SpeechToText _speech;
  bool _isInitialized = false;

  SpeechRecognitionService({stt.SpeechToText? speech})
    : _speech = speech ?? stt.SpeechToText();

  @override
  bool get isListening => _speech.isListening;

  @override
  bool get isAvailable => _isInitialized && _speech.isAvailable;

  @override
  Future<bool> initialize() async {
    if (_isInitialized) return _speech.isAvailable;
    try {
      _isInitialized = await _speech.initialize(
        onError: (errorNotification) {
          DLog.warning(
            'SpeechRecognitionService error: ${errorNotification.errorMsg}',
          );
        },
        onStatus: (status) {
          DLog.info('SpeechRecognitionService status: $status');
        },
        debugLogging: false,
      );
      return _isInitialized;
    } catch (e, stack) {
      DLog.error('SpeechRecognitionService init error: $e', stack);
      _isInitialized = false;
      return false;
    }
  }

  @override
  Future<void> startListening({
    String localeId = 'vi_VN',
    void Function(String words, bool isFinal)? onResult,
    void Function(double soundLevel)? onSoundLevel,
    void Function(String error)? onError,
    void Function(String status)? onStatus,
  }) async {
    final available = await initialize();
    if (!available) {
      onError?.call('Speech recognition not available');
      return;
    }

    var targetLocale = localeId;
    try {
      final locales = await _speech.locales();
      final viLocale = locales.cast<stt.LocaleName?>().firstWhere(
        (l) =>
            l != null &&
            (l.localeId.toLowerCase().startsWith('vi') ||
                l.localeId.toLowerCase().replaceAll('-', '_') ==
                    localeId.toLowerCase().replaceAll('-', '_')),
        orElse: () => null,
      );
      if (viLocale != null) {
        targetLocale = viLocale.localeId;
      } else {
        final system = await _speech.systemLocale();
        if (system != null) {
          targetLocale = system.localeId;
        }
      }
    } catch (e) {
      DLog.warning('Failed to query locales: $e');
    }

    try {
      await _speech.listen(
        onResult: (result) {
          onResult?.call(result.recognizedWords, result.finalResult);
        },
        onSoundLevelChange: (level) {
          onSoundLevel?.call(level);
        },
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.search,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(milliseconds: 2500),
          localeId: targetLocale,
        ),
      );
    } catch (e) {
      DLog.error('Error during speech listen: $e');
      onError?.call(e.toString());
    }
  }

  @override
  Future<void> stopListening() async {
    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (e) {
      DLog.warning('Error stopping speech: $e');
    }
  }

  @override
  Future<void> cancelListening() async {
    try {
      if (_speech.isListening) {
        await _speech.cancel();
      }
    } catch (e) {
      DLog.warning('Error canceling speech: $e');
    }
  }

  @override
  void dispose() {
    try {
      if (_speech.isListening) {
        _speech.stop();
      }
    } catch (e) {
      DLog.warning('Error disposing speech: $e');
    }
  }
}
