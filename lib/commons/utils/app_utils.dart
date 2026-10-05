import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/utils/map_geometry_utils.dart';
import 'package:s_map/models/models.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../mixin/app_mixin.dart';
export 'poi_category_helper.dart';

class AppUtils with AppMixin {
  static final AppUtils instance = AppUtils();

  T getCubit<T extends Cubit>(BuildContext context) => context.read<T>();

  DateTime parseDateFromServer(String date) => DateTime.parse(date).toLocal();

  String getErrorText(e) {
    if (e is AppError) {
      return e.message;
    }
    return e?.toString() ?? "Đã có lỗi xảy ra";
  }

  /// Khoảng cách Haversine giữa 2 điểm toạ độ (đơn vị: **km**).
  ///
  /// Delegate sang [MapGeometryUtils.haversineDistanceKm] để đảm bảo NaN-safe
  /// và chuẩn hoá logic toán học.
  double calculateDistance(lat1, lon1, lat2, lon2) {
    return MapGeometryUtils.haversineDistanceKm(
      (lat1 as num).toDouble(),
      (lon1 as num).toDouble(),
      (lat2 as num).toDouble(),
      (lon2 as num).toDouble(),
    );
  }

  Future<bool> call(String? tel) async {
    if (tel == null || tel == "" || tel == "-") return false;
    final url = 'tel:${tel.startsWith('84') ? tel.replaceFirst('84', '') : tel}';
    if (!(await canLaunchUrlString(url))) return false;
    return launchUrlString(url);
  }

  Future<bool> openLocation(num? lat, num? lon) {
    return launchUrlString('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
  }

  static final List<MapEntry<String, RegExp>> _vietnameseRegExps = [
    MapEntry('a', RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]')),
    MapEntry('A', RegExp(r'[ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴ]')),
    MapEntry('e', RegExp(r'[èéẹẻẽêềếệểễ]')),
    MapEntry('E', RegExp(r'[ÈÉẸẺẼÊỀẾỆỂỄ]')),
    MapEntry('i', RegExp(r'[ìíịỉĩ]')),
    MapEntry('I', RegExp(r'[ÌÍỊỈĨ]')),
    MapEntry('o', RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]')),
    MapEntry('O', RegExp(r'[ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠ]')),
    MapEntry('u', RegExp(r'[ùúụủũưừứựửữ]')),
    MapEntry('U', RegExp(r'[ÙÚỤỦŨƯỪỨỰỬỮ]')),
    MapEntry('y', RegExp(r'[ỳýỵỷỹ]')),
    MapEntry('Y', RegExp(r'[ỲÝỴỶỸ]')),
    MapEntry('d', RegExp(r'[đ]')),
    MapEntry('D', RegExp(r'[Đ]')),
  ];

  /// Chuẩn hóa bỏ dấu tiếng Việt chuyển thành chuỗi ASCII (ví dụ: "Phở Bát Đàn" -> "pho bat dan")
  String removeVietnameseAccents(String? text) {
    if (text == null || text.isEmpty) return "";
    var result = text;
    for (final entry in _vietnameseRegExps) {
      result = result.replaceAll(entry.value, entry.key);
    }
    // OSM address data can contain combining marks (for example
    // "Nguyễn" instead of the precomposed "Nguyễn"). Remove them after
    // replacing the common precomposed Vietnamese characters so both forms
    // produce the same searchable ASCII text.
    result = result.replaceAll(RegExp(r'[\u0300-\u036f]'), '');
    return result.toLowerCase().trim();
  }

  /// Alias tiện ích cho removeVietnameseAccents
  String toAscii(String? text) => removeVietnameseAccents(text);
}
