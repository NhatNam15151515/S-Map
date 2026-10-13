/// Bộ lọc góc quay tròn Circular EMA (Exponential Moving Average)
///
/// Xử lý đặc thù góc tuần hoàn $0^\circ \leftrightarrow 360^\circ$ theo cung quay ngắn nhất (Shortest Arc),
/// loại bỏ hiện tượng xoay ngược $360^\circ$ khi đi qua điểm biên và triệt tiêu rung chấn la bàn từ trường.
class CircularEmaFilter {
  double? _currentBearing;

  /// Hệ số mượt mặc định $\alpha \in (0.0, 1.0]$
  /// * $\alpha$ càng nhỏ: Độ trễ càng cao, độ mượt càng lớn (chống rung cực mạnh).
  /// * $\alpha$ càng lớn: Phản ứng càng nhanh theo giá trị mới.
  final double defaultAlpha;

  CircularEmaFilter({this.defaultAlpha = 0.25})
      : assert(defaultAlpha > 0.0 && defaultAlpha <= 1.0,
            'defaultAlpha must be in range (0.0, 1.0]');

  /// Góc hiện tại sau khi làm mịn (độ: 0.0 đến 360.0)
  double? get currentBearing => _currentBearing;

  /// Cập nhật góc mục tiêu mới và trả về góc đã làm mịn
  double filter(double targetBearing, {double? alpha}) {
    final effectiveAlpha = alpha ?? defaultAlpha;
    assert(effectiveAlpha > 0.0 && effectiveAlpha <= 1.0,
        'alpha must be in range (0.0, 1.0]');

    // Chuẩn hoá target về [0, 360)
    final normalizedTarget = (targetBearing % 360.0 + 360.0) % 360.0;

    if (_currentBearing == null) {
      _currentBearing = normalizedTarget;
      return _currentBearing!;
    }

    // Tính độ lệch góc ngắn nhất giữa target và current trong khoảng [-180, 180]
    final diff = ((normalizedTarget - _currentBearing! + 540.0) % 360.0) - 180.0;

    // Áp dụng EMA trên cung góc ngắn nhất
    var nextBearing = _currentBearing! + effectiveAlpha * diff;
    nextBearing = (nextBearing % 360.0 + 360.0) % 360.0;

    _currentBearing = nextBearing;
    return nextBearing;
  }

  /// Đặt lại trạng thái bộ lọc
  void reset() {
    _currentBearing = null;
  }
}
