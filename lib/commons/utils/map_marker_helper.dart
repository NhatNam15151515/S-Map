import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:s_map/constants/constants.dart';

/// Helper trung tâm dùng chung cho toàn bộ app để sinh và nạp các dynamic Bitmap Marker
/// (Start Marker, Finish Red Marker, Stop Circle Marker, Selected/Search Pin) vào engine bản đồ MapLibre.
///
/// Thiết kế chuẩn kiến trúc:
/// - Mọi marker (Start, Red Pin, Stop Circle) đều được đổ bóng (Drop Shadow + Ground Shadow) nổi khối 3D.
/// - Không hardcode màu sắc; dùng design tokens [AppColors] làm mặc định.
/// - Hỗ trợ inject màu sắc tùy biến theo theme giao diện.
/// - Dùng chung cho: Tìm kiếm POI, Click chọn điểm trên map (Dropped Pin),
///   Vẽ tuyến đường tùy chỉnh, Dẫn đường trực tiếp và Lịch sử chuyến đi.
class MapMarkerHelper {
  /// Khóa định danh marker điểm xuất phát (Start Pin / Circle xanh lá đổ bóng)
  static const String startMarkerId = 'smap-trip-start-marker';

  /// Khóa định danh marker điểm dừng (Stop Circle đỏ có dấu "=" nằm dọc || đổ bóng)
  static const String stopMarkerId = 'smap-trip-stop-circle-marker';

  /// Khóa định danh marker điểm đến / điểm chọn trên map (Red Pin giọt nước đổ bóng 3D)
  static const String finishMarkerId = RoutingConstants.markerImageKey;

  /// Khóa định danh marker điểm được click / chọn trên map
  static const String selectedPinId = 'smap-selected-pin-marker';

  /// Khóa định danh marker kết quả tìm kiếm
  static const String searchResultPinId = 'smap-search-result-pin-marker';

  /// Danh mục các icon POI marker và màu nền đại diện dùng design token từ AppColors
  static const Map<String, ({IconData icon, Color bg})> categoryPoiMarkers = {
    'poi-marker-cafe': (icon: Icons.coffee_rounded, bg: AppColors.poiBadgeCafe),
    'poi-marker-food': (icon: Icons.restaurant_rounded, bg: AppColors.poiBadgeFood),
    'poi-marker-hotel': (icon: Icons.hotel_rounded, bg: AppColors.poiBadgeHotel),
    'poi-marker-shop': (icon: Icons.shopping_bag_rounded, bg: AppColors.poiBadgeShop),
    'poi-marker-supermarket': (icon: Icons.shopping_cart_rounded, bg: AppColors.poiBadgeSupermarket),
    'poi-marker-fuel': (icon: Icons.local_gas_station_rounded, bg: AppColors.poiBadgeFuel),
    'poi-marker-bank': (icon: Icons.account_balance_rounded, bg: AppColors.poiBadgeBank),
    'poi-marker-hospital': (icon: Icons.local_hospital_rounded, bg: AppColors.poiBadgeHospital),
    'poi-marker-school': (icon: Icons.school_rounded, bg: AppColors.poiBadgeSchool),
    'poi-marker-park': (icon: Icons.park_rounded, bg: AppColors.poiBadgePark),
    'poi-marker-default': (icon: Icons.place_rounded, bg: AppColors.poiBadgeDefault),
  };

  /// Tạo ảnh Red Pin Marker giọt nước có đổ bóng 3D (Ground Shadow elip dưới chân + Body Drop Shadow)
  /// Dùng cho: Click chọn điểm trên map, Kết quả tìm kiếm POI, Điểm đến lộ trình và Đích đến hoàn thành.
  static Future<Uint8List> createRedPinMarkerBytes({
    double width = 64,
    double height = 90,
    Color color = AppColors.error,
    Color innerColor = AppColors.white,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final centerX = width / 2;
    // Điểm nhọn ghim cắm xuống đất
    final tipY = height - 10.0;
    final headRadius = width * 0.40;
    final headCenterY = headRadius + 4.0;

    // 1. Đổ bóng tiếp xúc mặt đất (Ground Contact Shadow elip dưới mũi nhọn)
    final groundShadowPaint = Paint()
      ..color = AppColors.blackOpa25
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, height - 5.0),
        width: width * 0.50,
        height: 8.0,
      ),
      groundShadowPaint,
    );

    // 2. Path hình giọt nước ghim bản đồ (Teardrop Map Pin)
    final path = Path();
    path.moveTo(centerX, tipY);
    // Cung bo lên bên trái
    path.cubicTo(
      centerX - headRadius * 0.95,
      tipY - headRadius * 0.85,
      centerX - headRadius,
      headCenterY + headRadius * 0.5,
      centerX - headRadius,
      headCenterY,
    );
    // Cung tròn đỉnh trên
    path.arcTo(
      Rect.fromCircle(center: Offset(centerX, headCenterY), radius: headRadius),
      math.pi,
      math.pi,
      false,
    );
    // Cung bo xuống bên phải về lại mũi nhọn
    path.cubicTo(
      centerX + headRadius,
      headCenterY + headRadius * 0.5,
      centerX + headRadius * 0.95,
      tipY - headRadius * 0.85,
      centerX,
      tipY,
    );
    path.close();

    // 3. Đổ bóng toàn thân ghim (Body Drop Shadow)
    final bodyShadowPaint = Paint()
      ..color = AppColors.blackOpa25
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
    canvas.drawPath(path.shift(const Offset(0, 2.5)), bodyShadowPaint);

    // 4. Vẽ thân ghim màu đỏ
    final pinPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, pinPaint);

    // 5. Viền ghim mỏng tinh tế tạo độ nổi khối
    final borderPaint = Paint()
      ..color = AppColors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(path, borderPaint);

    // 6. Khoen tròn màu trắng đặc trưng ở tâm đầu ghim
    final innerCirclePaint = Paint()
      ..color = innerColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(centerX, headCenterY), headRadius * 0.40, innerCirclePaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Tạo ảnh start marker (vòng tròn xanh lá viền trắng có đổ bóng 3D)
  static Future<Uint8List> createStartMarkerBytes({
    double size = 64,
    Color color = AppColors.statsSuccess,
    Color innerColor = AppColors.white,
    Color borderColor = AppColors.white,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);
    final radius = size / 2 - 5.0;

    // Đổ bóng (Drop Shadow)
    final shadowPaint = Paint()
      ..color = AppColors.blackOpa25
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5);
    canvas.drawCircle(center.translate(0, 2.5), radius, shadowPaint);

    // Viền ngoài màu trắng
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, borderPaint);

    // Vòng tròn màu chính (start color)
    final mainPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 3.5, mainPaint);

    // Tâm tròn ở giữa
    final innerDotPaint = Paint()
      ..color = innerColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.38, innerDotPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Tạo ảnh stop circle marker: Vòng tròn đỏ viền trắng với dấu "=" nằm dọc (||) ở giữa có đổ bóng
  /// Chỉ dùng khi chuyến đi bị dừng giữa chừng
  static Future<Uint8List> createStopCircleMarkerBytes({
    double size = 64,
    Color color = AppColors.error,
    Color barColor = AppColors.white,
    Color borderColor = AppColors.white,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);
    final radius = size / 2 - 5.0;

    // Đổ bóng (Drop Shadow)
    final shadowPaint = Paint()
      ..color = AppColors.blackOpa25
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5);
    canvas.drawCircle(center.translate(0, 2.5), radius, shadowPaint);

    // Viền ngoài màu trắng
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, borderPaint);

    // Nền màu điểm dừng
    final mainPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 3.5, mainPaint);

    // 2 vạch trắng thẳng đứng song song (dấu = nằm dọc ||)
    final barPaint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    final barWidth = size * 0.12;
    final barHeight = size * 0.38;
    final gap = size * 0.10;

    final leftBarX = center.dx - gap / 2 - barWidth;
    final rightBarX = center.dx + gap / 2;
    final barY = center.dy - barHeight / 2;
    final barRadius = Radius.circular(barWidth / 2);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(leftBarX, barY, barWidth, barHeight),
        barRadius,
      ),
      barPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rightBarX, barY, barWidth, barHeight),
        barRadius,
      ),
      barPaint,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Nạp toàn bộ các marker ảnh dùng chung vào MapLibre controller
  /// Mặc định render Red Pin và Start Marker có bóng đổ 3D sắc nét.
  static Future<void> loadCommonMapMarkers(
    MapLibreMapController controller, {
    Color? startColor,
    Color? stopColor,
    Color? pinColor,
  }) async {
    try {
      // 1. Red marker có bóng đổ cho điểm kết thúc / điểm đến / điểm click trên map
      try {
        final redBytes = await createRedPinMarkerBytes(
          color: pinColor ?? AppColors.error,
        );
        await _safeAddImage(controller, finishMarkerId, redBytes);
      } catch (_) {
        // Fallback sang ảnh asset nếu platform canvas gặp lỗi
        final byteData = await rootBundle.load(AppAsset.redMarker.fullPath);
        final redBytes = byteData.buffer.asUint8List();
        await _safeAddImage(controller, finishMarkerId, redBytes);
      }

      // 2. Start marker có bóng đổ (mặc định AppColors.statsSuccess)
      final startBytes = await createStartMarkerBytes(
        color: startColor ?? AppColors.statsSuccess,
      );
      await _safeAddImage(controller, startMarkerId, startBytes);

      // 3. Stop circle marker có dấu || đổ bóng (mặc định AppColors.error)
      final stopBytes = await createStopCircleMarkerBytes(
        color: stopColor ?? AppColors.error,
      );
      await _safeAddImage(controller, stopMarkerId, stopBytes);

      // 4. Các biểu tượng POI ghim badge tròn theo Category (hiện khi zoom sâu)
      for (final entry in categoryPoiMarkers.entries) {
        try {
          final badgeBytes = await createCategoryBadgeMarkerBytes(
            icon: entry.value.icon,
            backgroundColor: entry.value.bg,
          );
          await _safeAddImage(controller, entry.key, badgeBytes);
        } catch (e, stack) {
          DLog.warning(
              '⚠️ [MapMarkerHelper] Failed to load POI badge ${entry.key}: $e',
              stack);
        }
      }

      DLog.info('🗺️ [MapMarkerHelper] Common map markers with 3D shadows and POI badges loaded successfully into engine');
    } catch (e, stack) {
      DLog.warning('⚠️ [MapMarkerHelper] Failed to load common markers: $e', stack);
    }
  }

  /// Tạo ảnh badge tròn ghim vị trí theo danh mục (Category POI Badge Pin)
  /// Có viền tròn, nền màu theo danh mục, icon Material ở giữa, chân ghim nhọn cắm xuống đất và đổ bóng.
  static Future<Uint8List> createCategoryBadgeMarkerBytes({
    required IconData icon,
    required Color backgroundColor,
    Color iconColor = AppColors.poiBadgeIcon,
    Color borderColor = AppColors.poiBadgeBorder,
    double width = 56,
    double height = 66,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final centerX = width / 2;
    final tipY = height - 5.0;
    final headRadius = width * 0.40;
    final headCenterY = headRadius + 4.0;

    // 1. Ground Shadow (bóng tiếp xúc mặt đất elip)
    final groundShadowPaint = Paint()
      ..color = AppColors.blackOpa25
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, height - 3.0),
        width: width * 0.45,
        height: 6.0,
      ),
      groundShadowPaint,
    );

    // 2. Thân ghim (Pin Pointer: tam giác nhọn ở chân kết hợp vòng tròn)
    final pinPath = Path();
    pinPath.moveTo(centerX, tipY);
    pinPath.lineTo(centerX - headRadius * 0.50, headCenterY + headRadius * 0.75);
    pinPath.arcTo(
      Rect.fromCircle(center: Offset(centerX, headCenterY), radius: headRadius),
      math.pi * 0.68,
      math.pi * 1.64,
      false,
    );
    pinPath.lineTo(centerX, tipY);
    pinPath.close();

    // 2.1. Đổ bóng toàn thân (Drop shadow)
    final bodyShadowPaint = Paint()
      ..color = AppColors.blackOpa25
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawPath(pinPath.shift(const Offset(0, 1.5)), bodyShadowPaint);

    // 2.2. Viền ngoài bo ghim
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(pinPath, borderPaint);

    // 2.3. Nền trong màu Category (Inner Fill)
    final innerRadius = headRadius - 2.5;
    final innerPath = Path();
    innerPath.moveTo(centerX, tipY - 3.0);
    innerPath.lineTo(
        centerX - innerRadius * 0.50, headCenterY + innerRadius * 0.75);
    innerPath.arcTo(
      Rect.fromCircle(center: Offset(centerX, headCenterY), radius: innerRadius),
      math.pi * 0.68,
      math.pi * 1.64,
      false,
    );
    innerPath.lineTo(centerX, tipY - 3.0);
    innerPath.close();

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(innerPath, bgPaint);

    // 3. Icon Material ở tâm vòng tròn
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: innerRadius * 1.05,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: iconColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    iconPainter.paint(
      canvas,
      Offset(
        centerX - iconPainter.width / 2,
        headCenterY - iconPainter.height / 2,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Thêm image an toàn, bắt lỗi nếu sprite key đã tồn tại trong Map engine
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

  /// Alias tương thích ngược cho màn hình lịch sử chuyến đi
  static Future<void> loadTripMarkers(
    MapLibreMapController controller, {
    Color? startColor,
    Color? stopColor,
  }) =>
      loadCommonMapMarkers(
        controller,
        startColor: startColor,
        stopColor: stopColor,
      );
}

/// Alias thuận tiện để tương thích ngược hoàn toàn với code cũ
typedef TripMapMarkerHelper = MapMarkerHelper;
