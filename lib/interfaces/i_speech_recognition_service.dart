abstract class ISpeechRecognitionService {
  /// Khởi tạo engine nhận diện giọng nói.
  /// Trả về true nếu thiết bị hỗ trợ và sẵn sàng.
  Future<bool> initialize();

  /// Kiểm tra xem engine có đang lắng nghe micro hay không.
  bool get isListening;

  /// Kiểm tra xem thiết bị có hỗ trợ speech recognition hay không.
  bool get isAvailable;

  /// Bắt đầu lắng nghe từ micro.
  Future<void> startListening({
    String localeId = 'vi_VN',
    void Function(String words, bool isFinal)? onResult,
    void Function(double soundLevel)? onSoundLevel,
    void Function(String error)? onError,
    void Function(String status)? onStatus,
  });

  /// Dừng lắng nghe và trả về kết quả cuối cùng.
  Future<void> stopListening();

  /// Hủy phiên lắng nghe hiện tại mà không lấy kết quả.
  Future<void> cancelListening();

  /// Giải phóng tài nguyên.
  void dispose();
}
