import 'package:equatable/equatable.dart';

enum VoiceSearchStatus {
  initial,
  initializing,
  listening,
  success,
  error,
  permissionDenied,
  unavailable,
}

class VoiceSearchState extends Equatable {
  final VoiceSearchStatus status;
  final String recognizedText;
  final double soundLevel;
  final String? errorMessage;
  final bool isFinal;

  const VoiceSearchState({
    this.status = VoiceSearchStatus.initial,
    this.recognizedText = '',
    this.soundLevel = 0.0,
    this.errorMessage,
    this.isFinal = false,
  });

  bool get isInitial => status == VoiceSearchStatus.initial;
  bool get isInitializing => status == VoiceSearchStatus.initializing;
  bool get isListening => status == VoiceSearchStatus.listening;
  bool get isSuccess => status == VoiceSearchStatus.success;
  bool get isError => status == VoiceSearchStatus.error;
  bool get isPermissionDenied => status == VoiceSearchStatus.permissionDenied;
  bool get isUnavailable => status == VoiceSearchStatus.unavailable;

  VoiceSearchState copyWith({
    VoiceSearchStatus? status,
    String? recognizedText,
    double? soundLevel,
    String? errorMessage,
    bool? isFinal,
  }) {
    return VoiceSearchState(
      status: status ?? this.status,
      recognizedText: recognizedText ?? this.recognizedText,
      soundLevel: soundLevel ?? this.soundLevel,
      errorMessage: errorMessage ?? this.errorMessage,
      isFinal: isFinal ?? this.isFinal,
    );
  }

  @override
  List<Object?> get props => [
        status,
        recognizedText,
        soundLevel,
        errorMessage,
        isFinal,
      ];
}
