import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/models/app_error.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../mixin/app_mixin.dart';
import 'dart:math' show cos, sqrt, asin;

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
}
