import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/utils/app_colors.dart';

/// Helper tạo dynamic numbered circle markers (1, 2, 3...) cho chế độ vẽ lộ trình.
/// Tuân thủ quy chuẩn UI:
/// - Drop Shadow 3D tạo độ nổi khối.
/// - Viền trắng sắc nét.
/// - Số thứ tự bold ở giữa vòng tròn.
class NumberedCircleMarkerHelper {
  static const String markerKeyPrefix = 'smap-numbered-wp';

  /// Bộ nhớ tạm lưu các key đã nạp vào MapLibre engine để tránh nạp trùng
  static final Set<String> _loadedMarkerKeys = <String>{};

  /// Tạo khóa định danh duy nhất cho marker số [number]
  static String markerKey(int number) => '$markerKeyPrefix-$number';

  /// Xóa cache các marker đã nạp (dùng khi style bản đồ reload)
  static void resetLoadedMarkers() {
    _loadedMarkerKeys.clear();
  }

  /// Tạo ảnh Bitmap PNG cho marker hình tròn đánh số [number]
  static Future<Uint8List> createBytes({
    required int number,
    double size = 64,
    Color bgColor = AppColors.sMapTeal,
    Color textColor = AppColors.white,
    Color borderColor = AppColors.white,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);
    final radius = size / 2 - 5.0;

    // 1. Đổ bóng (Drop Shadow 3D)
    final shadowPaint = Paint()
      ..color = AppColors.blackOpa25
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5);
    canvas.drawCircle(center.translate(0, 2.5), radius, shadowPaint);

    // 2. Viền ngoài màu trắng nổi bật
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, borderPaint);

    // 3. Vòng tròn nền chính
    final mainPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 3.5, mainPaint);

    // 4. Số thứ tự ở giữa
    final textSpan = TextSpan(
      text: '$number',
      style: TextStyle(
        color: textColor,
        fontSize: number >= 100
            ? size * 0.30
            : (number >= 10 ? size * 0.36 : size * 0.44),
        fontWeight: FontWeight.bold,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Nạp batch các numbered marker (từ 1 đến [count]) vào MapLibre engine
  static Future<void> loadNumberedMarkers(
    MapLibreMapController controller,
    int count, {
    Color? bgColor,
  }) async {
    if (count <= 0) return;
    try {
      for (int i = 1; i <= count; i++) {
        final key = markerKey(i);
        if (_loadedMarkerKeys.contains(key)) continue;

        final bytes = await createBytes(
          number: i,
          bgColor: bgColor ?? AppColors.sMapTeal,
        );
        await _safeAddImage(controller, key, bytes);
        _loadedMarkerKeys.add(key);
      }
    } catch (e, stack) {
      DLog.warning(
          '⚠️ [NumberedCircleMarkerHelper] Failed to batch load numbered markers: $e',
          stack);
    }
  }

  /// Thêm sprite image an toàn vào MapLibre engine
  static Future<void> _safeAddImage(
    MapLibreMapController controller,
    String key,
    Uint8List bytes,
  ) async {
    try {
      await controller.addImage(key, bytes);
    } catch (e) {
      final errorText = e.toString().toLowerCase();
      if (!errorText.contains('already') && !errorText.contains('image')) {
        rethrow;
      }
    }
  }
}
