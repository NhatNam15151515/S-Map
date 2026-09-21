import 'dart:math' as math;
import 'package:s_map/commons/utils/map_geometry_utils.dart';

/// Bộ lọc Kalman 2D cho tọa độ GPS — giảm nhiễu vị trí xe máy trong hẻm/khu đô thị.
///
/// **State Vector:** `[lat, lon, vLat, vLon]` (vị trí + vận tốc trên mỗi trục).
/// **Measurement:** `[gpsLat, gpsLon]` với `accuracy` (m) xác định ma trận nhiễu đo R.
///
/// Hoạt động theo chu kỳ:
/// 1. **Predict (Dead Reckoning):** Dự đoán vị trí tiếp theo từ vận tốc hiện tại.
///    Khi GPS mất tín hiệu 1-2 giây (đi qua gầm cầu, hầm chui), marker vẫn trượt mượt
///    theo hướng di chuyển cuối cùng thay vì đứng yên rồi nhảy bất chợt.
/// 2. **Update (Kalman Correction):** Khi có GPS fix mới, kết hợp dự đoán + đo lường GPS.
///    Trọng số nghiêng về GPS khi accuracy tốt (< 5m), nghiêng về prediction khi kém (> 20m).
///
/// **Đặc thù xe máy VN:**
/// - Process noise (`_baseProcessNoise`) cao hơn ô tô vì xe máy thay đổi hướng nhanh
///   (lách xe, vào hẻm, quay đầu) → filter phản ứng nhanh hơn thay vì bám cứng prediction.
/// - Khi tốc độ > 0: process noise tỷ lệ thuận với tốc độ (xe chạy nhanh = ít noise hơn
///   vì thường trên đường thẳng; xe chạy chậm = noise cao vì hay rẽ/lách).
class GpsKalmanFilter {
  /// Số mét trên 1 độ vĩ (xấp xỉ, dùng cho chuyển đổi lat/lon → mét)
  static const double _metersPerDegLat = MapGeometryUtils.metersPerDegreeLat;

  /// Nhiễu quá trình cơ sở (m²/s⁴) — phản ánh mức độ bất định của chuyển động xe máy.
  /// Giá trị cao hơn ô tô (2.0 so với 0.5) vì xe máy cơ động hơn nhiều.
  static const double _baseProcessNoise = 2.0;

  /// Nhiễu đo lường tối thiểu (m²) — sàn cho ma trận R ngay cả khi GPS báo accuracy cực tốt.
  /// Ngăn filter tin tưởng GPS quá mức (GPS luôn có sai số tối thiểu ~3m).
  static const double _minMeasurementNoise = 9.0; // 3m² = 9

  /// Khoảng thời gian dự đoán tối đa cho một bước predict (giây).
  /// Nếu GPS gián đoạn > 5 giây, prediction sẽ không chính xác nữa → clamp lại.
  static const double _maxPredictDt = 5.0;

  /// Ngưỡng nhảy GPS bất thường (mét). Nếu GPS fix mới cách filtered position > giá trị này,
  /// coi như GPS bị teleport (multi-path reflection) → reset filter thay vì correction.
  static const double _teleportThresholdMeters = 200.0;

  // State vector: [lat, lon, vLat, vLon]
  double _lat = 0.0;
  double _lon = 0.0;
  double _vLat = 0.0; // velocity trên trục lat (deg/s)
  double _vLon = 0.0; // velocity trên trục lon (deg/s)

  // Covariance matrix P (4x4) — lưu phẳng theo [p00, p01, p02, p03, p10, ..., p33]
  final List<double> _p = List<double>.filled(16, 0.0);

  bool _isInitialized = false;
  DateTime? _lastUpdateTime;

  /// `true` khi bộ lọc đã nhận ít nhất 1 GPS fix và bắt đầu hoạt động.
  bool get isInitialized => _isInitialized;

  /// Toạ độ đã lọc sau bước update cuối cùng.
  double get filteredLat => _lat;
  double get filteredLon => _lon;

  /// Reset toàn bộ trạng thái bộ lọc — gọi khi bắt đầu phiên dẫn đường mới.
  void reset() {
    _isInitialized = false;
    _lastUpdateTime = null;
    _lat = 0.0;
    _lon = 0.0;
    _vLat = 0.0;
    _vLon = 0.0;
    for (int i = 0; i < 16; i++) {
      _p[i] = 0.0;
    }
  }

  /// Nhận GPS fix mới và trả về toạ độ đã lọc.
  ///
  /// [gpsLat], [gpsLon]: Toạ độ thô từ Geolocator.
  /// [accuracyMeters]: Bán kính sai số GPS (Geolocator.accuracy). Xác định trọng số
  ///   của GPS trong phép kết hợp Kalman. GPS accuracy 5m → tin GPS nhiều hơn.
  ///   GPS accuracy 30m → tin prediction nhiều hơn.
  /// [speedMps]: Tốc độ hiện tại (m/s) từ Geolocator, dùng để scale process noise.
  ///   `null` nếu thiết bị không cung cấp.
  /// [headingDeg]: Hướng di chuyển GPS (độ, 0=Bắc), dùng cho velocity estimation
  ///   khi bộ lọc chưa hội tụ. `null` nếu không có.
  GpsFilteredPosition update({
    required double gpsLat,
    required double gpsLon,
    required double accuracyMeters,
    double? speedMps,
    double? headingDeg,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();

    if (!_isInitialized) {
      _initialize(gpsLat, gpsLon, accuracyMeters, speedMps, headingDeg);
      _lastUpdateTime = now;
      return GpsFilteredPosition(lat: _lat, lon: _lon);
    }

    // Tính delta time kể từ update trước
    final dt = _lastUpdateTime != null
        ? now.difference(_lastUpdateTime!).inMilliseconds / 1000.0
        : 0.0;
    _lastUpdateTime = now;

    if (dt <= 0.0) {
      return GpsFilteredPosition(lat: _lat, lon: _lon);
    }

    final clampedDt = dt.clamp(0.001, _maxPredictDt);

    // Kiểm tra GPS teleport (nhảy vị trí bất thường)
    final jumpDist = _haversineMeters(_lat, _lon, gpsLat, gpsLon);
    if (jumpDist > _teleportThresholdMeters) {
      // GPS bị teleport → hard-reset về vị trí GPS mới
      _initialize(gpsLat, gpsLon, accuracyMeters, speedMps, headingDeg);
      return GpsFilteredPosition(lat: _lat, lon: _lon);
    }

    // 1. PREDICT — Dead reckoning
    _predict(clampedDt, speedMps);

    // 2. UPDATE — Kalman correction
    _correct(gpsLat, gpsLon, accuracyMeters);

    return GpsFilteredPosition(lat: _lat, lon: _lon);
  }

  /// Khởi tạo state từ GPS fix đầu tiên
  void _initialize(
    double lat,
    double lon,
    double accuracy,
    double? speedMps,
    double? headingDeg,
  ) {
    _lat = lat;
    _lon = lon;

    // Ước tính velocity ban đầu từ speed + heading
    if (speedMps != null && speedMps > 0.5 && headingDeg != null) {
      final headingRad = headingDeg * math.pi / 180.0;
      final speedDegPerSec = speedMps / _metersPerDegLat;
      _vLat = speedDegPerSec * math.cos(headingRad);
      _vLon = speedDegPerSec * math.sin(headingRad) /
          math.cos(lat * math.pi / 180.0);
    } else {
      _vLat = 0.0;
      _vLon = 0.0;
    }

    // Khởi tạo P với uncertainty ban đầu dựa trên GPS accuracy
    final posVar = (accuracy * accuracy).clamp(_minMeasurementNoise, 2500.0);
    // Velocity uncertainty ban đầu: cao vì chưa biết hướng đi
    const velVar = 10.0;

    // P = diag(posVar, posVar, velVar, velVar)
    for (int i = 0; i < 16; i++) {
      _p[i] = 0.0;
    }
    _p[0] = posVar;   // P[0][0] = var(lat)
    _p[5] = posVar;   // P[1][1] = var(lon)
    _p[10] = velVar;  // P[2][2] = var(vLat)
    _p[15] = velVar;  // P[3][3] = var(vLon)

    _isInitialized = true;
  }

  /// Bước Predict: x = F * x, P = F * P * F' + Q
  ///
  /// Ma trận chuyển trạng thái F (Constant Velocity model):
  /// ```
  /// F = | 1  0  dt  0 |
  ///     | 0  1  0  dt |
  ///     | 0  0  1   0 |
  ///     | 0  0  0   1 |
  /// ```
  void _predict(double dt, double? speedMps) {
    // x_predicted = F * x
    _lat += _vLat * dt;
    _lon += _vLon * dt;
    // vLat, vLon giữ nguyên (constant velocity assumption)

    // Process noise Q — scale theo tốc độ
    // Xe máy chạy chậm (< 5 km/h) = hay rẽ/lách → noise cao
    // Xe máy chạy nhanh (> 30 km/h) = trên đường thẳng → noise thấp hơn
    final speedScale = speedMps != null && speedMps > 1.0
        ? (_baseProcessNoise / (1.0 + speedMps * 0.1))
        : _baseProcessNoise;

    // Q tính theo mô hình gia tốc ngẫu nhiên (piecewise white noise):
    // Q = q * | dt⁴/4  dt³/2 |  (cho mỗi trục)
    //         | dt³/2  dt²   |
    final dt2 = dt * dt;
    final dt3 = dt2 * dt;
    final dt4 = dt3 * dt;

    final q = speedScale;
    // Convert Q từ mét sang độ
    final qDeg = q / (_metersPerDegLat * _metersPerDegLat);

    final q00 = qDeg * dt4 / 4.0;
    final q02 = qDeg * dt3 / 2.0;
    final q22 = qDeg * dt2;

    // P_predicted = F * P * F' + Q
    // Với F là constant velocity model, triển khai tường minh:
    // (Tối ưu: không dùng matrix multiply tổng quát, inline trực tiếp)

    // Lưu P cũ
    final p00 = _p[0], p01 = _p[1], p02 = _p[2], p03 = _p[3];
    final p10 = _p[4], p11 = _p[5], p12 = _p[6], p13 = _p[7];
    final p20 = _p[8], p21 = _p[9], p22 = _p[10], p23 = _p[11];
    final p30 = _p[12], p31 = _p[13], p32 = _p[14], p33 = _p[15];

    // F * P:
    // Row 0: [p00+dt*p20, p01+dt*p21, p02+dt*p22, p03+dt*p23]
    // Row 1: [p10+dt*p30, p11+dt*p31, p12+dt*p32, p13+dt*p33]
    // Row 2: [p20, p21, p22, p23]
    // Row 3: [p30, p31, p32, p33]

    // (F * P) * F':
    _p[0] = p00 + dt * (p20 + p02) + dt2 * p22 + q00;
    _p[1] = p01 + dt * (p21 + p03) + dt2 * p23;
    _p[2] = p02 + dt * p22 + q02;
    _p[3] = p03 + dt * p23;

    _p[4] = p10 + dt * (p30 + p12) + dt2 * p32;
    _p[5] = p11 + dt * (p31 + p13) + dt2 * p33 + q00;
    _p[6] = p12 + dt * p32;
    _p[7] = p13 + dt * p33 + q02;

    _p[8] = p20 + dt * p22 + q02;
    _p[9] = p21 + dt * p23;
    _p[10] = p22 + q22;
    _p[11] = p23;

    _p[12] = p30 + dt * p32;
    _p[13] = p31 + dt * p33 + q02;
    _p[14] = p32;
    _p[15] = p33 + q22;
  }

  /// Bước Update (Correction): Kết hợp GPS measurement với predicted state.
  ///
  /// Ma trận quan sát H (chỉ đo vị trí, không đo vận tốc):
  /// ```
  /// H = | 1  0  0  0 |
  ///     | 0  1  0  0 |
  /// ```
  ///
  /// Innovation: y = z - H * x_predicted = [gpsLat - lat, gpsLon - lon]
  /// Kalman Gain: K = P * H' * inv(H * P * H' + R)
  /// State update: x = x + K * y
  /// Covariance update: P = (I - K * H) * P
  void _correct(double gpsLat, double gpsLon, double accuracyMeters) {
    // Ma trận nhiễu đo R = diag(r, r) (đơn vị: deg²)
    final rMeters2 =
        (accuracyMeters * accuracyMeters).clamp(_minMeasurementNoise, 10000.0);
    final r = rMeters2 / (_metersPerDegLat * _metersPerDegLat);

    // S = H * P * H' + R → ma trận 2x2
    // S = | P[0][0]+r  P[0][1] |
    //     | P[1][0]  P[1][1]+r |
    final s00 = _p[0] + r;
    final s01 = _p[1];
    final s10 = _p[4];
    final s11 = _p[5] + r;

    // Invert S (2x2): S_inv = adj(S) / det(S)
    final det = s00 * s11 - s01 * s10;
    if (det.abs() < 1e-30) return; // Ma trận suy biến, bỏ qua update

    final invDet = 1.0 / det;
    final si00 = s11 * invDet;
    final si01 = -s01 * invDet;
    final si10 = -s10 * invDet;
    final si11 = s00 * invDet;

    // K = P * H' * S_inv → ma trận 4x2
    // P * H' = | P[0][0]  P[0][1] |    (cột 0 và 1 của P)
    //          | P[1][0]  P[1][1] |
    //          | P[2][0]  P[2][1] |
    //          | P[3][0]  P[3][1] |
    final k00 = _p[0] * si00 + _p[1] * si10;
    final k01 = _p[0] * si01 + _p[1] * si11;
    final k10 = _p[4] * si00 + _p[5] * si10;
    final k11 = _p[4] * si01 + _p[5] * si11;
    final k20 = _p[8] * si00 + _p[9] * si10;
    final k21 = _p[8] * si01 + _p[9] * si11;
    final k30 = _p[12] * si00 + _p[13] * si10;
    final k31 = _p[12] * si01 + _p[13] * si11;

    // Innovation: y = [gpsLat - predicted_lat, gpsLon - predicted_lon]
    final y0 = gpsLat - _lat;
    final y1 = gpsLon - _lon;

    // State correction: x = x + K * y
    _lat += k00 * y0 + k01 * y1;
    _lon += k10 * y0 + k11 * y1;
    _vLat += k20 * y0 + k21 * y1;
    _vLon += k30 * y0 + k31 * y1;

    // Covariance update: P = (I - K * H) * P
    // Lưu P cũ trước khi cập nhật
    final p00 = _p[0], p01 = _p[1], p02 = _p[2], p03 = _p[3];
    final p10 = _p[4], p11 = _p[5], p12 = _p[6], p13 = _p[7];
    final p20 = _p[8], p21 = _p[9], p22 = _p[10], p23 = _p[11];
    final p30 = _p[12], p31 = _p[13], p32 = _p[14], p33 = _p[15];

    // (I - K*H) = | 1-k00  -k01  0  0 |
    //             | -k10  1-k11  0  0 |
    //             | -k20  -k21   1  0 |
    //             | -k30  -k31   0  1 |
    _p[0] = (1 - k00) * p00 - k01 * p10;
    _p[1] = (1 - k00) * p01 - k01 * p11;
    _p[2] = (1 - k00) * p02 - k01 * p12;
    _p[3] = (1 - k00) * p03 - k01 * p13;

    _p[4] = -k10 * p00 + (1 - k11) * p10;
    _p[5] = -k10 * p01 + (1 - k11) * p11;
    _p[6] = -k10 * p02 + (1 - k11) * p12;
    _p[7] = -k10 * p03 + (1 - k11) * p13;

    _p[8] = -k20 * p00 - k21 * p10 + p20;
    _p[9] = -k20 * p01 - k21 * p11 + p21;
    _p[10] = -k20 * p02 - k21 * p12 + p22;
    _p[11] = -k20 * p03 - k21 * p13 + p23;

    _p[12] = -k30 * p00 - k31 * p10 + p30;
    _p[13] = -k30 * p01 - k31 * p11 + p31;
    _p[14] = -k30 * p02 - k31 * p12 + p32;
    _p[15] = -k30 * p03 - k31 * p13 + p33;
  }

  /// Delegate sang [MapGeometryUtils.haversineDistanceMeters].
  static double _haversineMeters(
      double lat1, double lon1, double lat2, double lon2) {
    return MapGeometryUtils.haversineDistanceMeters(lat1, lon1, lat2, lon2);
  }
}

/// Kết quả toạ độ GPS đã lọc qua Kalman Filter
class GpsFilteredPosition {
  final double lat;
  final double lon;

  const GpsFilteredPosition({required this.lat, required this.lon});
}
