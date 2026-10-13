import 'package:equatable/equatable.dart';

abstract class VoiceSearchEvent extends Equatable {
  const VoiceSearchEvent();

  @override
  List<Object?> get props => [];
}

/// Bắt đầu lắng nghe giọng nói
class VoiceSearchStarted extends VoiceSearchEvent {
  final String localeId;

  const VoiceSearchStarted({this.localeId = 'vi_VN'});

  @override
  List<Object?> get props => [localeId];
}

/// Người dùng chủ động bấm dừng hoặc engine tự động dừng khi im lặng
class VoiceSearchStopped extends VoiceSearchEvent {
  const VoiceSearchStopped();
}

/// Người dùng bấm hủy / đóng popup
class VoiceSearchCancelled extends VoiceSearchEvent {
  const VoiceSearchCancelled();
}

/// Nhận được kết quả (tạm thời hoặc chính thức) từ bộ nhận diện
class VoiceSearchResultReceived extends VoiceSearchEvent {
  final String recognizedText;
  final bool isFinal;

  const VoiceSearchResultReceived(this.recognizedText, {this.isFinal = false});

  @override
  List<Object?> get props => [recognizedText, isFinal];
}

/// Mức âm lượng microphone thay đổi (để vẽ animation sóng âm)
class VoiceSearchSoundLevelChanged extends VoiceSearchEvent {
  final double soundLevel;

  const VoiceSearchSoundLevelChanged(this.soundLevel);

  @override
  List<Object?> get props => [soundLevel];
}

/// Có lỗi xảy ra trong quá trình thu âm / nhận diện
class VoiceSearchErrorOccurred extends VoiceSearchEvent {
  final String errorMessage;

  const VoiceSearchErrorOccurred(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
