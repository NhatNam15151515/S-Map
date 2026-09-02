import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/models/models.dart';

import 'app_utils.dart';

/// Xếp hạng kết quả theo semantics gần với Places Text Search:
///
/// * category/nearby: ưu tiên khoảng cách;
/// * text: ưu tiên mức độ khớp tên, sau đó dùng khoảng cách làm tie-breaker.
///
/// Repository vẫn chịu trách nhiệm lọc dữ liệu. Class này chỉ làm ranking và
/// deduplicate ở lớp orchestration để có thể dùng chung cho mọi nguồn kết quả.
class SearchResultRanker {
  SearchResultRanker._();

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

    final cleanQuery = _normalize(query);
    final queryTokens = _tokens(cleanQuery);
    final results = unique.values.toList();
    results.sort((a, b) {
      if (cleanQuery.isNotEmpty) {
        final scoreComparison = _textScore(b, cleanQuery, queryTokens)
            .compareTo(_textScore(a, cleanQuery, queryTokens));
        if (scoreComparison != 0) return scoreComparison;
      }

      if (center != null) {
        final distanceComparison = _distanceKm(a, center)
            .compareTo(_distanceKm(b, center));
        if (distanceComparison != 0) return distanceComparison;
      }

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return results.take(limit).toList(growable: false);
  }

  static double _textScore(
    PoiModel poi,
    String query,
    List<String> queryTokens,
  ) {
    final name = _normalize(poi.name);
    final nameAscii = _normalize(poi.nameAscii);
    final address = _normalize(poi.address);
    final street = _normalize(poi.street);
    final city = _normalize(poi.city);
    final category = _normalize(poi.category);
    final subCategory = _normalize(poi.subCategory);

    var score = 0.0;
    if (name == query || nameAscii == query) score += 1000;
    if (name.startsWith(query) || nameAscii.startsWith(query)) score += 700;
    if (name.contains(query) || nameAscii.contains(query)) score += 450;
    if (address.contains(query) || street.contains(query) || city.contains(query)) {
      score += 260;
    }
    if (category.contains(query) || subCategory.contains(query)) score += 120;

    if (queryTokens.isNotEmpty) {
      final fields = [name, nameAscii, address, street, city, category, subCategory];
      final matchedTokens = queryTokens
          .where((token) => fields.any((field) => field.contains(token)))
          .length;
      score += matchedTokens * 80;
      if (matchedTokens == queryTokens.length) score += 180;
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

  static String _normalize(String? value) {
    final ascii = AppUtils.instance.toAscii(value ?? '').toLowerCase();
    return ascii.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  static List<String> _tokens(String value) {
    return value
        .split(' ')
        .where((token) => token.length >= 2)
        .toList(growable: false);
  }
}
