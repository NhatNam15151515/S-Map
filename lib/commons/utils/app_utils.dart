import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:s_map/models/models.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../mixin/app_mixin.dart';
import 'dart:math' show cos, sqrt, asin;
export 'poi_category_helper.dart';

extension SafePopBuildContext on BuildContext {
  void safePop<T>([T? result]) {
    try {
      pop(result);
    } catch (_) {
      Navigator.of(this).pop(result);
    }
  }
}

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

  double calculateDistance(lat1, lon1, lat2, lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
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
    return result.toLowerCase().trim();
  }

  /// Alias tiện ích cho removeVietnameseAccents
  String toAscii(String? text) => removeVietnameseAccents(text);
}
