import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/commons/validators/validator.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/services/services.dart';
import 'package:sqflite/sqflite.dart';

/// Shared SQL/query preparation used by the POI repository query modules.
class PoiSearchQuerySupport {
  Future<bool>? _fts5Availability;

  static const List<PoiModel> _sovereignPois = [
    PoiModel(
      id: 999901,
      name: 'Quần đảo Hoàng Sa (Việt Nam)',
      nameAscii: 'Quan dao Hoang Sa (Viet Nam)',
      lat: 16.5367,
      lon: 112.3394,
      category: 'island',
      address: 'Thành phố Đà Nẵng, Việt Nam',
    ),
    PoiModel(
      id: 999902,
      name: 'Quần đảo Trường Sa (Việt Nam)',
      nameAscii: 'Quan dao Truong Sa (Viet Nam)',
      lat: 8.6433,
      lon: 111.9197,
      category: 'island',
      address: 'Tỉnh Khánh Hòa, Việt Nam',
    ),
    PoiModel(
      id: 999903,
      name: 'Biển Đông',
      nameAscii: 'Bien Dong',
      lat: 13.5000,
      lon: 113.5000,
      category: 'sea',
      address: 'Việt Nam',
    ),
  ];

  List<PoiModel> matchSovereignPois(String query) {
    final lower = query.toLowerCase().trim();
    if (lower.isEmpty) return const [];
    return _sovereignPois.where((poi) {
      if (poi.name.toLowerCase().contains(lower)) return true;
      if ((lower.contains('hoang sa') || lower.contains('hoàng sa')) &&
          poi.id == 999901) {
        return true;
      }
      if ((lower.contains('truong sa') || lower.contains('trường sa')) &&
          poi.id == 999902) {
        return true;
      }
      return (lower.contains('bien dong') || lower.contains('biển đông')) &&
          poi.id == 999903;
    }).toList();
  }

  Future<bool> supportsFts5(Database database) {
    return _fts5Availability ??= () async {
      try {
        await database.rawQuery('SELECT rowid FROM poi_fts LIMIT 1');
        return true;
      } catch (error) {
        DLog.warning('[PoiSearch] FTS5 unavailable; using indexed fallback', error);
        return false;
      }
    }();
  }

  Future<List<PoiModel>> searchNamePrefix(
    Database database,
    String query, {
    required int limit,
    String? provinceCode,
  }) async {
    final prefix = AppUtils.instance.toAscii(query).toLowerCase().trim();
    if (prefix.isEmpty) return const [];
    final upperBound = prefixUpperBound(prefix);
    if (upperBound == null) return const [];

    final provinceClause = provinceCode == null || provinceCode.isEmpty
        ? ''
        : ' AND province_code = ?';
    final arguments = <Object?>[prefix, upperBound];
    if (provinceClause.isNotEmpty) arguments.add(provinceCode);
    arguments.add(limit);
    final rows = await database.rawQuery(
      'SELECT * FROM poi WHERE name_ascii >= ? AND name_ascii < ?'
      '$provinceClause LIMIT ?',
      arguments,
    );
    return rows.map(PoiModel.fromMap).toList(growable: false);
  }

  String sanitizeFtsQuery(String query) =>
      query.replaceAll(RegExp(r'''[*"'-\:()^~{}\[\]\\]'''), ' ').trim();

  List<String> categoryKeywords(String category) {
    final lower = category.toLowerCase().trim();
    switch (lower) {
      case 'coffee':
      case 'cafe':
      case 'cà phê':
      case 'ca phe':
        return ['coffee', 'cafe', 'cà phê', 'ca phe'];
      case 'food':
      case 'nhà hàng':
      case 'quán ăn':
        return [
          'food',
          'restaurant',
          'fast_food',
          'nhà hàng',
          'nha hang',
          'quán ăn',
          'quan an',
        ];
      case 'gas':
      case 'fuel':
      case 'xăng':
      case 'cây xăng':
        return ['gas', 'fuel', 'xăng', 'xang', 'petrol'];
      case 'hotel':
      case 'khách sạn':
      case 'nhà nghỉ':
        return [
          'hotel',
          'motel',
          'guest_house',
          'khách sạn',
          'khach san',
          'nhà nghỉ',
          'nha nghi',
        ];
      case 'atm':
      case 'ngân hàng':
      case 'bank':
        return ['atm', 'bank', 'ngân hàng', 'ngan hang'];
      case 'hospital':
      case 'bệnh viện':
      case 'y tế':
        return [
          'hospital',
          'clinic',
          'pharmacy',
          'bệnh viện',
          'benh vien',
          'phòng khám',
          'phong kham',
          'nhà thuốc',
          'nha thuoc',
        ];
      default:
        return [lower];
    }
  }

  String? prefixUpperBound(String value) {
    final units = value.codeUnits;
    for (var index = units.length - 1; index >= 0; index--) {
      if (units[index] < 0xFFFF) {
        return String.fromCharCodes([
          ...units.take(index),
          units[index] + 1,
        ]);
      }
    }
    return null;
  }

  String searchCacheKey(String query, {required int limit}) {
    final mode = Validator.instance.hasDiacritics(query) ? 'accent' : 'ascii';
    return '${SearchCacheService.cacheVersion}|search|$mode|'
        '${_normalizeCacheText(query)}|limit:$limit';
  }

  String suggestionsCacheKey(String query, {required int limit}) =>
      '${SearchCacheService.cacheVersion}|suggestions|'
      '${_normalizeCacheText(query)}|limit:$limit';

  String boundsSearchCacheKey({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    String? query,
    String? category,
    required int limit,
  }) {
    String coordinate(double value) => value.toStringAsFixed(5);

    return '${SearchCacheService.cacheVersion}|bounds|'
        '${coordinate(minLat)}:${coordinate(maxLat)}:'
        '${coordinate(minLon)}:${coordinate(maxLon)}|'
        'query:${_normalizeCacheText(query)}|'
        'category:${_normalizeCacheText(category)}|limit:$limit';
  }

  String _normalizeCacheText(String? value) {
    if (value == null || value.isEmpty) return '';
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}
