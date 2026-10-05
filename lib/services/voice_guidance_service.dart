import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:s_map/commons/blocs/navigation_bloc/navigation_state.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/utils/voice_instruction_builder.dart';

/// Dịch vụ giọng nói dẫn đường tiếng Việt (Text-to-Speech).
///
/// Lắng nghe thay đổi trạng thái từ [NavigationBloc] và phát câu hướng dẫn
/// qua loa thiết bị. Có cơ chế:
/// - **Cooldown:** Không phát 2 câu cách nhau dưới 3 giây (tránh spam loa).
/// - **Queue:** Câu mới thay thế câu cũ đang chờ (chỉ phát câu mới nhất).
/// - **Auto-duck:** Giảm volume nhạc khi đang nói (Android AudioFocus).
///
/// Sử dụng:
/// ```dart
/// final tts = VoiceGuidanceService();
/// await tts.init();
/// // Trong BlocListener<NavigationBloc>:
/// tts.onNavigationStateChanged(prevState, newState);
/// // Khi kết thúc:
/// tts.dispose();
/// ```
class VoiceGuidanceService {
  FlutterTts? _tts;
  bool _isInitialized = false;
  bool _isSpeaking = false;
  bool _isEnabled = true;
  DateTime? _lastSpokenTime;

  /// Khoảng cách tối thiểu giữa 2 câu nói (tránh spam)
  static const Duration _cooldown = Duration(seconds: 3);

  /// Khởi tạo TTS engine với locale tiếng Việt.
  /// Gọi 1 lần khi app bắt đầu phiên dẫn đường.
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _tts = FlutterTts();

      // Cấu hình tiếng Việt
      await _tts!.setLanguage('vi-VN');
      await _tts!.setSpeechRate(0.5); // Tốc độ vừa phải, rõ ràng
      await _tts!.setPitch(1.0);
      await _tts!.setVolume(1.0);

      // iOS: audio category setting
      await _tts!.setIosAudioCategory(
        IosTextToSpeechAudioCategory.ambient,
        [IosTextToSpeechAudioCategoryOptions.duckOthers],
      );

      // Callbacks
      _tts!.setStartHandler(() {
        _isSpeaking = true;
      });
      _tts!.setCompletionHandler(() {
        _isSpeaking = false;
      });
      _tts!.setCancelHandler(() {
        _isSpeaking = false;
      });
      _tts!.setErrorHandler((msg) {
        _isSpeaking = false;
        DLog.warning('⚠️ [VoiceGuidance] TTS error: $msg');
      });

      _isInitialized = true;
      DLog.info('🔊 [VoiceGuidance] TTS initialized (vi-VN, rate=0.5)');
    } catch (e, stack) {
      DLog.error('❌ [VoiceGuidance] Failed to initialize TTS: $e', e, stack);
    }
  }

  /// Bật/tắt giọng nói dẫn đường.
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) {
      stop();
    }
  }

  bool get isEnabled => _isEnabled;

  /// Xử lý thay đổi trạng thái Navigation — gọi từ BlocListener.
  ///
  /// So sánh [previous] và [current] để phát hiện các sự kiện cần phát giọng nói:
  /// 1. Pre-announce: `isPreAnnounced` chuyển từ false → true
  /// 2. Rerouting: `status` chuyển sang `rerouting`
  /// 3. Arrived: `status` chuyển sang `arrived`
  void onNavigationStateChanged(
    NavigationState previous,
    NavigationState current,
  ) {
    if (!_isEnabled || !_isInitialized || _tts == null) return;

    // 1. Đã đến đích
    if (current.status == NavigationStatus.arrived &&
        previous.status != NavigationStatus.arrived) {
      _speak(VoiceInstructionBuilder.buildArrival(
        destinationName: current.destinationName,
      ));
      return;
    }

    // 2. Đang tính lại đường
    if (current.status == NavigationStatus.rerouting &&
        previous.status != NavigationStatus.rerouting) {
      _speak(VoiceInstructionBuilder.buildRerouting());
      return;
    }

    // 3. Pre-announce (cách ngã rẽ ~200m)
    if (current.isPreAnnounced &&
        !previous.isPreAnnounced &&
        current.currentInstruction != null) {
      final ins = current.currentInstruction!;
      _speak(VoiceInstructionBuilder.buildPreAnnounce(
        type: ins.type,
        streetName: ins.streetName,
        distanceMeters: current.distanceToNextInstruction,
      ));
      return;
    }

    // 4. At-turn: instruction index tăng = vừa rẽ xong, thông báo instruction mới
    if (current.currentInstructionIndex > previous.currentInstructionIndex &&
        current.currentInstruction != null &&
        !current.isPreAnnounced) {
      final ins = current.currentInstruction!;
      // Chỉ thông báo nếu không phải arrive (đã xử lý ở trên)
      if (!ins.type.isArrive) {
        _speak(VoiceInstructionBuilder.buildAtTurn(
          type: ins.type,
          streetName: ins.streetName,
        ));
      }
    }
  }

  /// Phát một câu nói với cooldown protection.
  Future<void> _speak(String text) async {
    if (!_isInitialized || _tts == null || text.isEmpty) return;

    // Cooldown check
    final now = DateTime.now();
    if (_lastSpokenTime != null &&
        now.difference(_lastSpokenTime!) < _cooldown) {
      DLog.info('🔇 [VoiceGuidance] Skipped (cooldown): "$text"');
      return;
    }

    // Nếu đang nói → dừng câu cũ, phát câu mới
    if (_isSpeaking) {
      await _tts!.stop();
    }

    _lastSpokenTime = now;
    DLog.info('🔊 [VoiceGuidance] Speaking: "$text"');

    try {
      await _tts!.speak(text);
    } catch (e) {
      DLog.warning('⚠️ [VoiceGuidance] Failed to speak: $e');
    }
  }

  /// Dừng phát giọng nói hiện tại.
  Future<void> stop() async {
    if (_tts != null && _isSpeaking) {
      await _tts!.stop();
      _isSpeaking = false;
    }
  }

  /// Giải phóng tài nguyên TTS — gọi khi kết thúc phiên dẫn đường.
  Future<void> dispose() async {
    try {
      await stop();
      await _tts?.stop();
      _isInitialized = false;
      _tts = null;
      DLog.info('🔊 [VoiceGuidance] TTS disposed');
    } catch (e) {
      DLog.warning('⚠️ [VoiceGuidance] Error disposing TTS: $e');
    }
  }
}
