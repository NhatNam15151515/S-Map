import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Tiện ích nén ảnh và chuyển đổi Base64 cho Avatar
/// Tận dụng trực tiếp Flutter Native Engine (dart:ui) để downsample và encode PNG.
class AvatarUtils {
  const AvatarUtils._();

  /// Downsample và nén byte ảnh gốc về kích thước chuẩn [targetSize]x[targetSize],
  /// sau đó mã hóa sang chuỗi Base64 để lưu trữ trực tiếp vào Firestore.
  static Future<String> compressToBase64(
    Uint8List rawBytes, {
    int targetSize = 128,
  }) async {
    // 1. Flutter Engine giải mã và downsample ngay ở tầng native C++
    final codec = await ui.instantiateImageCodec(
      rawBytes,
      targetWidth: targetSize,
      targetHeight: targetSize,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;

    // 2. Encode sang PNG bitstream
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Không thể encode byte ảnh sang định dạng PNG');
    }

    final compressedBytes = byteData.buffer.asUint8List();

    // 3. Biến đổi sang Base64 ASCII String để lưu vào Firestore
    return base64Encode(compressedBytes);
  }

  /// Giải mã Base64 string thành Uint8List để nạp vào MemoryImage
  static Uint8List decodeBase64(String base64String) {
    final cleanString = base64String.contains(',')
        ? base64String.split(',').last
        : base64String;
    return base64Decode(cleanString.trim());
  }

  /// Đo dung lượng thực tế ước lượng (KB) của chuỗi Base64
  static double estimateSizeKb(String base64String) {
    final cleanLength = base64String.contains(',')
        ? base64String.split(',').last.trim().length
        : base64String.trim().length;
    return (cleanLength * 3 / 4) / 1024;
  }

  /// Tính tỷ lệ nén dung lượng (%) so với kích thước byte ban đầu
  static double calculateCompressionRatio({
    required int originalBytesLength,
    required String base64String,
  }) {
    if (originalBytesLength <= 0) return 0.0;
    final compressedBytesLength = (base64String.length * 3 / 4);
    final savedRatio = (1 - (compressedBytesLength / originalBytesLength)) * 100;
    return savedRatio < 0 ? 0.0 : savedRatio;
  }
}
