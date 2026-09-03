import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/validators/validator.dart';
import 'package:s_map/models/models.dart';

import 'app_utils.dart';

class _ScoredCandidate {
  final PoiModel poi;
  final double score;

  const _ScoredCandidate(this.poi, this.score);
}

/// Xếp hạng kết quả theo kiến trúc chuẩn của Google Maps Places Search:
///
/// 1. **O(N) Precomputation**: Điểm văn bản và khoảng cách được tính trước một
///    lần duy nhất cho mỗi POI, tránh gọi RegExp và chuẩn hóa chuỗi $O(N \log N)$
///    lần trong hàm so sánh `sort()`.
/// 2. **Blended Scoring (Hàm điểm đa biến)**:
///    - **Tier 1 (Exact Match)**: Bảo vệ tuyệt đối bằng điểm cơ sở vượt trội ($20,000+$),
///      khoảng cách chỉ đóng vai trò tie-breaker giữa các điểm cùng khớp chính xác.
///    - **Tier 2 (Word-Boundary / Prefix Match)**: Khớp đầu từ/cụm từ ($10,000+$).
///    - **Tier 3 (Partial / Token / Address Match)**: Kết hợp mượt mà điểm chữ
///      và hàm suy giảm khoảng cách (Soft Distance Decay), giúp địa điểm gần
///      người dùng tự nhiên nổi lên khi tìm kiếm cục bộ.
///    - **Tier 4 (Nearby / Category Only)**: Sắp xếp thuần túy theo khoảng cách.
/// 3. **Canonical Unicode NFC Normalization**: Xử lý triệt để ký tự tổ hợp (NFD)
///    từ bộ gõ tiếng Việt trên iOS/Android để so khớp chính xác với dữ liệu NFC.
class SearchResultRanker {
  SearchResultRanker._();

  static final RegExp _cleanPunctuationRegExp =
      RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true);
  static final RegExp _cleanAsciiRegExp = RegExp(r'[^a-z0-9]+');
  static final RegExp _multipleSpacesRegExp = RegExp(r'\s+');

  static const Map<String, String> _combiningToPrecomposed = {
    // a
    'a\u0300': 'à', 'a\u0301': 'á', 'a\u0309': 'ả', 'a\u0303': 'ã', 'a\u0323': 'ạ',
    'â\u0300': 'ầ', 'â\u0301': 'ấ', 'â\u0309': 'ẩ', 'â\u0303': 'ẫ', 'â\u0323': 'ậ',
    'ă\u0300': 'ằ', 'ă\u0301': 'ắ', 'ă\u0309': 'ẳ', 'ă\u0303': 'ẵ', 'ă\u0323': 'ặ',
    'a\u0302': 'â', 'a\u0306': 'ă',
    // e
    'e\u0300': 'è', 'e\u0301': 'é', 'e\u0309': 'ẻ', 'e\u0303': 'ẽ', 'e\u0323': 'ẹ',
    'ê\u0300': 'ề', 'ê\u0301': 'ế', 'ê\u0309': 'ể', 'ê\u0303': 'ễ', 'ê\u0323': 'ệ',
    'e\u0302': 'ê',
    // i
    'i\u0300': 'ì', 'i\u0301': 'í', 'i\u0309': 'ỉ', 'i\u0303': 'ĩ', 'i\u0323': 'ị',
    // o
    'o\u0300': 'ò', 'o\u0301': 'ó', 'o\u0309': 'ỏ', 'o\u0303': 'õ', 'o\u0323': 'ọ',
    'ô\u0300': 'ồ', 'ô\u0301': 'ố', 'ô\u0309': 'ổ', 'ô\u0303': 'ỗ', 'ô\u0323': 'ộ',
    'ơ\u0300': 'ờ', 'ơ\u0301': 'ớ', 'ơ\u0309': 'ở', 'ơ\u0303': 'ỡ', 'ơ\u0323': 'ợ',
    'o\u0302': 'ô', 'o\u031b': 'ơ',
    // u
    'u\u0300': 'ù', 'u\u0301': 'ú', 'u\u0309': 'ủ', 'u\u0303': 'ũ', 'u\u0323': 'ụ',
    'ư\u0300': 'ừ', 'ư\u0301': 'ứ', 'ư\u0309': 'ử', 'ư\u0303': 'ữ', 'ư\u0323': 'ự',
    'u\u031b': 'ư',
    // y
    'y\u0300': 'ỳ', 'y\u0301': 'ý', 'y\u0309': 'ỷ', 'y\u0303': 'ỹ', 'y\u0323': 'ỵ',
    // d
    'd\u0311': 'đ', 'd\u0303': 'đ',
  };

  static List<PoiModel> rank(
    Iterable<PoiModel> source, {
    LatLng? center,
    String? query,
    int limit = 50,
  }) {
    final unique = <String, PoiModel>{};
    for (final poi in source) {
      unique.putIfAbsent(PoiCategoryHelper.getPoiKey(poi), () => poi);
    }

    final cleanQuery = _normalizeText(query);
    final hasQuery = cleanQuery.isNotEmpty;
    final hasDiacritics = hasQuery && Validator.instance.hasDiacritics(query);
    final asciiQuery = hasQuery ? _normalizeAscii(query) : '';
    final queryTokens = hasQuery
        ? _tokens(hasDiacritics ? cleanQuery : asciiQuery)
        : const <String>[];

    // O(N) Precomputation of scores: Tính trước điểm một lần duy nhất
    final candidates = <_ScoredCandidate>[];
    for (final poi in unique.values) {
      final distanceKm = center != null ? _distanceKm(poi, center) : null;
      final textScore = hasQuery
          ? _computeTextScore(
              poi,
              cleanQuery,
              asciiQuery,
              queryTokens,
              hasDiacritics,
            )
          : 0.0;

      final totalScore = _blendScore(
        textScore: textScore,
        distanceKm: distanceKm,
        hasQuery: hasQuery,
      );

      candidates.add(_ScoredCandidate(poi, totalScore));
    }

    // O(N log N) primitive double comparison (siêu nhanh, không regex trong sort)
    candidates.sort((a, b) {
      final scoreDiff = b.score.compareTo(a.score);
      if (scoreDiff != 0) return scoreDiff;
      return a.poi.name.compareTo(b.poi.name);
    });

    return candidates.take(limit).map((c) => c.poi).toList(growable: false);
  }

  /// Hàm kết hợp đa biến chuẩn hoá theo mô hình của Google Maps
  static double _blendScore({
    required double textScore,
    required double? distanceKm,
    required bool hasQuery,
  }) {
    if (!hasQuery) {
      // Tìm kiếm theo danh mục / lân cận (không có text)
      if (distanceKm == null) return 0.0;
      return 10000.0 / (1.0 + 0.1 * distanceKm);
    }

    if (textScore <= 0.0) {
      return 0.0;
    }

    // Tier 1: Khớp chính xác tên (Exact Match)
    // Bảo vệ tối thượng: Địa điểm dù xa vẫn giữ hạng cao nhất
    if (textScore >= 1800.0) {
      final tieBreaker = distanceKm != null
          ? 500.0 / (1.0 + 0.05 * distanceKm)
          : 250.0;
      return 20000.0 + textScore + tieBreaker;
    }

    // Tier 2: Khớp tiền tố hoặc ranh giới từ (Word-boundary / Prefix Match)
    if (textScore >= 1000.0) {
      final tieBreaker = distanceKm != null
          ? 800.0 / (1.0 + 0.05 * distanceKm)
          : 400.0;
      return 10000.0 + textScore + tieBreaker;
    }

    // Tier 3: Khớp một phần / Địa chỉ / Token
    // Tại tầng này, khoảng cách địa lý kết hợp mượt mà để ưu tiên quán gần
    final geoBonus = distanceKm != null
        ? 1200.0 / (1.0 + 0.05 * distanceKm)
        : 600.0;
    return textScore + geoBonus;
  }

  static double _computeTextScore(
    PoiModel poi,
    String cleanQuery,
    String asciiQuery,
    List<String> queryTokens,
    bool hasDiacritics,
  ) {
    final normName = _normalizeText(poi.name);
    final normNameAscii = _normalizeAscii(
        poi.nameAscii.isNotEmpty ? poi.nameAscii : poi.name);
    final normAddress = _normalizeText(poi.address);
    final normStreet = _normalizeText(poi.street);
    final normCity = _normalizeText(poi.city);
    final normCategory = _normalizeText(poi.category);
    final normSubCategory = _normalizeText(poi.subCategory);

    var score = 0.0;

    if (hasDiacritics) {
      // Người dùng gõ CÓ DẤU: Ưu tiên tuyệt đối các kết quả khớp đúng dấu
      if (normName == cleanQuery) {
        score += 2000;
      } else if (normName.startsWith(cleanQuery)) {
        score += 1400;
      } else if (normName.contains(' $cleanQuery')) {
        score += 1100; // Word boundary match
      } else if (normName.contains(cleanQuery)) {
        score += 700;
      }

      if (normAddress.contains(cleanQuery) ||
          normStreet.contains(cleanQuery) ||
          normCity.contains(cleanQuery)) {
        score += 400;
      }
      if (normCategory.contains(cleanQuery) ||
          normSubCategory.contains(cleanQuery)) {
        score += 150;
      }

      if (queryTokens.isNotEmpty) {
        final fields = [
          normName,
          normAddress,
          normStreet,
          normCity,
          normCategory,
          normSubCategory,
        ];
        var matchedTokens = 0;
        for (final token in queryTokens) {
          final isMatched = fields.any((field) =>
              field.startsWith(token) ||
              field.contains(' $token') ||
              field.contains(token));
          if (isMatched) matchedTokens++;
        }
        score += matchedTokens * 120;
        if (matchedTokens == queryTokens.length) score += 300;
      }

      // Fallback không dấu chỉ kích hoạt khi điểm có dấu bằng 0
      if (score == 0.0 && asciiQuery.isNotEmpty) {
        if (normNameAscii == asciiQuery) {
          score += 100;
        } else if (normNameAscii.startsWith(asciiQuery)) {
          score += 60;
        } else if (normNameAscii.contains(asciiQuery)) {
          score += 30;
        }
      }
    } else {
      // Người dùng gõ KHÔNG DẤU: So khớp linh hoạt trên cả 2 trường
      final normAddressAscii = _normalizeAscii(poi.address);
      final normStreetAscii = _normalizeAscii(poi.street);
      final normCityAscii = _normalizeAscii(poi.city);

      if (normName == cleanQuery || normNameAscii == asciiQuery) {
        score += 1800; // Exact match unaccented
      } else if (normName.startsWith(cleanQuery) ||
          normNameAscii.startsWith(asciiQuery)) {
        score += 1200;
      } else if (normName.contains(' $cleanQuery') ||
          normNameAscii.contains(' $asciiQuery')) {
        score += 1050; // Word boundary
      } else if (normName.contains(cleanQuery) ||
          normNameAscii.contains(asciiQuery)) {
        score += 650;
      }

      if (normAddress.contains(cleanQuery) ||
          normStreet.contains(cleanQuery) ||
          normCity.contains(cleanQuery) ||
          normAddressAscii.contains(asciiQuery) ||
          normStreetAscii.contains(asciiQuery) ||
          normCityAscii.contains(asciiQuery)) {
        score += 350;
      }
      if (normCategory.contains(cleanQuery) ||
          normSubCategory.contains(cleanQuery)) {
        score += 150;
      }

      if (queryTokens.isNotEmpty) {
        final fields = [
          normName,
          normNameAscii,
          normAddress,
          normAddressAscii,
          normStreet,
          normStreetAscii,
          normCity,
          normCityAscii,
          normCategory,
          normSubCategory,
        ];
        var matchedTokens = 0;
        for (final token in queryTokens) {
          final isMatched = fields.any((field) =>
              field.startsWith(token) ||
              field.contains(' $token') ||
              field.contains(token));
          if (isMatched) matchedTokens++;
        }
        score += matchedTokens * 90;
        if (matchedTokens == queryTokens.length) score += 200;
      }
    }

    return score;
  }

  static double _distanceKm(PoiModel poi, LatLng center) {
    return AppUtils.instance.calculateDistance(
      center.latitude,
      center.longitude,
      poi.lat,
      poi.lon,
    );
  }

  /// Chuẩn hóa ký tự Unicode tổ hợp (NFD) sang dựng sẵn (NFC)
  static String _toCanonicalNfc(String input) {
    if (input.isEmpty) return input;
    var result = input;
    for (final entry in _combiningToPrecomposed.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }

  static String _normalizeText(String? value) {
    if (value == null || value.isEmpty) return '';
    final canonical = _toCanonicalNfc(value.toLowerCase());
    return canonical
        .replaceAll(_cleanPunctuationRegExp, ' ')
        .replaceAll(_multipleSpacesRegExp, ' ')
        .trim();
  }

  static String _normalizeAscii(String? value) {
    final ascii = AppUtils.instance.toAscii(value ?? '').toLowerCase();
    return ascii
        .replaceAll(_cleanAsciiRegExp, ' ')
        .replaceAll(_multipleSpacesRegExp, ' ')
        .trim();
  }

  static List<String> _tokens(String value) {
    return value
        .split(' ')
        .where((token) => token.length >= 2)
        .toList(growable: false);
  }
}
