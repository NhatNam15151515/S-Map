import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';

/// Helper chuyên biệt xử lý dữ liệu, định dạng hiển thị và ánh xạ phương tiện cho chuyến đi
class TripFormatHelper {
  TripFormatHelper._();

  /// Dịch chuỗi an toàn với fallback, chống hiển thị raw localization key (dạng "stats_dashboard.xxx")
  static String safeTr(String key, String fallback, {List<String>? args}) {
    final translated = args != null ? tr(key, args: args) : tr(key);
    if (translated == key || translated.startsWith('stats_dashboard.')) {
      return fallback;
    }
    return translated;
  }

  /// Lấy IconData đại diện cho loại phương tiện
  static IconData getVehicleIcon(String profile) {
    switch (profile.toLowerCase()) {
      case 'car':
        return Icons.directions_car_rounded;
      case 'walking':
      case 'foot':
        return Icons.directions_walk_rounded;
      case 'motorcycle':
      case 'moped':
      case 'moped_vn':
      default:
        return Icons.two_wheeler_rounded;
    }
  }

  /// Lấy màu nhận diện của phương tiện theo Theme
  static Color getVehicleColor(BuildContext context, String profile) {
    final themeColors = context.themeColors;
    switch (profile.toLowerCase()) {
      case 'car':
        return themeColors.statsBlue;
      case 'walking':
      case 'foot':
        return themeColors.statsOrange;
      case 'motorcycle':
      case 'moped':
      case 'moped_vn':
      default:
        return context.colorScheme.primary;
    }
  }

  /// Lấy tên dịch đa ngôn ngữ của loại phương tiện
  static String getVehicleName(String profile) {
    switch (profile.toLowerCase()) {
      case 'car':
        return tr(LocaleKeys.stats_dashboard_filter_car);
      case 'walking':
      case 'foot':
        return tr(LocaleKeys.stats_dashboard_filter_walking);
      case 'motorcycle':
      case 'moped':
      case 'moped_vn':
      default:
        return tr(LocaleKeys.stats_dashboard_filter_motorcycle);
    }
  }

  /// Trích xuất tiêu đề đại diện cho chuyến đi (Điểm đến -> Điểm đi -> Ngày giờ)
  static String getTripTitle(TripRecordModel trip) {
    if (trip.destinationName?.trim().isNotEmpty == true) {
      return trip.destinationName!;
    }
    if (trip.originName?.trim().isNotEmpty == true) {
      return trip.originName!;
    }
    return DateFormat('HH:mm - dd/MM/yyyy').format(trip.startTime);
  }

  /// Lấy địa chỉ điểm xuất phát hiển thị (originName -> tọa độ đầu -> fallback i18n)
  static String getOriginAddress(TripRecordModel trip) {
    if (trip.originName?.trim().isNotEmpty == true) {
      return trip.originName!;
    }
    final firstPoint =
        trip.polyline?.isNotEmpty == true ? trip.polyline!.first : null;
    if (firstPoint != null) {
      return '${firstPoint[0].toStringAsFixed(4)}, ${firstPoint[1].toStringAsFixed(4)}';
    }
    return tr(LocaleKeys.stats_dashboard_detail_origin);
  }

  /// Lấy địa chỉ đích đến ban đầu (target - destinationName)
  static String getDestinationAddress(TripRecordModel trip) {
    if (trip.destinationName?.trim().isNotEmpty == true) {
      return trip.destinationName!;
    }
    final lastPoint =
        trip.polyline?.isNotEmpty == true ? trip.polyline!.last : null;
    if (lastPoint != null) {
      return '${lastPoint[0].toStringAsFixed(4)}, ${lastPoint[1].toStringAsFixed(4)}';
    }
    return tr(LocaleKeys.stats_dashboard_detail_destination);
  }

  /// Lấy tọa độ/địa chỉ thực tế nơi chuyến đi đã dừng lại (stopped point)
  static String getStoppedAddress(TripRecordModel trip) {
    if (trip.stoppedName?.trim().isNotEmpty == true) {
      return trip.stoppedName!.trim();
    }
    final lastPoint =
        trip.polyline?.isNotEmpty == true ? trip.polyline!.last : null;
    if (lastPoint != null) {
      return '${lastPoint[0].toStringAsFixed(4)}, ${lastPoint[1].toStringAsFixed(4)}';
    }
    return tr(LocaleKeys.stats_dashboard_detail_stopped_point);
  }

  /// Định dạng ngày giờ hiển thị ngắn hoặc đầy đủ
  static String formatTripDate(DateTime dateTime, {bool withYear = false}) {
    final pattern = withYear ? 'HH:mm - dd/MM/yyyy' : 'HH:mm, dd/MM';
    return DateFormat(pattern).format(dateTime);
  }

  /// Hộp thoại xác nhận xóa chuyến đi
  static Future<bool?> showDeleteConfirmDialog(
    BuildContext context, {
    required VoidCallback onConfirm,
  }) {
    return AppConfirmDialog.show(
      context,
      title: tr(LocaleKeys.stats_dashboard_delete_trip_title),
      message: tr(LocaleKeys.stats_dashboard_delete_trip_desc),
      confirmText: tr(LocaleKeys.stats_dashboard_delete_trip_btn),
      isDestructive: true,
      confirmKey: const Key('confirm_delete_trip_btn'),
      onConfirm: onConfirm,
    );
  }

  /// Đếm tổng số chuyến đi theo profile phương tiện từ thống kê profileCounts
  static int getProfileTripCount(Map<String, int> profileCounts, String? profile) {
    if (profile == null) {
      return profileCounts.values.fold(0, (a, b) => a + b);
    }
    if (profile == 'motorcycle') {
      return (profileCounts['motorcycle'] ?? 0) +
          (profileCounts['moped_vn'] ?? 0) +
          (profileCounts['moped'] ?? 0);
    }
    if (profile == 'walking') {
      return (profileCounts['walking'] ?? 0) + (profileCounts['foot'] ?? 0);
    }
    return profileCounts[profile] ?? 0;
  }

  /// Danh sách bộ lọc phương tiện mặc định cho Dashboard (profileKey, label, icon)
  static List<(String?, String, IconData)> getVehicleFilterOptions() {
    return [
      (
        null,
        tr(LocaleKeys.stats_dashboard_filter_all),
        Icons.all_inclusive_rounded,
      ),
      (
        'motorcycle',
        tr(LocaleKeys.stats_dashboard_filter_motorcycle),
        Icons.two_wheeler_rounded,
      ),
      (
        'car',
        tr(LocaleKeys.stats_dashboard_filter_car),
        Icons.directions_car_rounded,
      ),
      (
        'walking',
        tr(LocaleKeys.stats_dashboard_filter_walking),
        Icons.directions_walk_rounded,
      ),
    ];
  }
}
