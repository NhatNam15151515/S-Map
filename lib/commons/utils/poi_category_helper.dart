import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';

class PoiCategoryHelper {
  PoiCategoryHelper._();

  /// Lấy unique key định danh cho một POI (id -> osm_id -> name)
  static String getPoiKey(PoiModel poi) {
    if (poi.id != null) return poi.id.toString();
    if (poi.osmId != null && poi.osmId!.isNotEmpty) return poi.osmId!;
    return poi.name;
  }

  /// Ánh xạ từ category / sub_category sang IconData tương ứng
  static IconData getIcon(String? category, {String? subCategory}) {
    final cat = (category ?? '').toLowerCase().trim();
    final sub = (subCategory ?? '').toLowerCase().trim();

    if (cat.contains('food') ||
        cat.contains('restaurant') ||
        cat.contains('ăn uống') ||
        sub.contains('restaurant') ||
        sub.contains('fast_food')) {
      return Icons.restaurant_rounded;
    }
    if (cat.contains('cafe') ||
        cat.contains('coffee') ||
        cat.contains('cà phê') ||
        sub.contains('cafe') ||
        sub.contains('coffee')) {
      return Icons.coffee_rounded;
    }
    if (cat.contains('hotel') ||
        cat.contains('motel') ||
        cat.contains('khách sạn') ||
        sub.contains('hotel') ||
        sub.contains('lodging')) {
      return Icons.hotel_rounded;
    }
    if (cat.contains('gas') ||
        cat.contains('fuel') ||
        cat.contains('cây xăng') ||
        sub.contains('fuel') ||
        sub.contains('gas')) {
      return Icons.local_gas_station_rounded;
    }
    if (cat.contains('atm') ||
        cat.contains('bank') ||
        cat.contains('ngân hàng') ||
        sub.contains('atm') ||
        sub.contains('bank')) {
      return Icons.atm_rounded;
    }
    if (cat.contains('hospital') ||
        cat.contains('bệnh viện') ||
        cat.contains('pharmacy') ||
        cat.contains('clinic') ||
        sub.contains('hospital') ||
        sub.contains('pharmacy')) {
      return Icons.local_hospital_rounded;
    }
    if (cat.contains('school') ||
        cat.contains('university') ||
        cat.contains('trường học') ||
        sub.contains('school') ||
        sub.contains('university')) {
      return Icons.school_rounded;
    }
    if (cat.contains('shop') ||
        cat.contains('market') ||
        cat.contains('mall') ||
        cat.contains('siêu thị') ||
        sub.contains('supermarket')) {
      return Icons.shopping_bag_rounded;
    }
    if (cat.contains('park') ||
        cat.contains('tourism') ||
        cat.contains('công viên') ||
        sub.contains('park')) {
      return Icons.park_rounded;
    }

    return Icons.place_rounded;
  }

  /// Màu sắc đại diện cho danh mục POI
  static Color getIconColor(String? category, {String? subCategory}) {
    final cat = (category ?? '').toLowerCase().trim();

    if (cat.contains('food') ||
        cat.contains('restaurant') ||
        cat.contains('ăn uống')) {
      return AppColors.sunOrange;
    }
    if (cat.contains('cafe') ||
        cat.contains('coffee') ||
        cat.contains('cà phê')) {
      return AppColors.burningTrail;
    }
    if (cat.contains('hotel') || cat.contains('khách sạn')) {
      return AppColors.googleBlue;
    }
    if (cat.contains('gas') ||
        cat.contains('fuel') ||
        cat.contains('cây xăng')) {
      return AppColors.flameOrange;
    }
    if (cat.contains('atm') ||
        cat.contains('bank') ||
        cat.contains('ngân hàng')) {
      return AppColors.googleGreen;
    }
    if (cat.contains('hospital') ||
        cat.contains('bệnh viện') ||
        cat.contains('pharmacy')) {
      return AppColors.redPigment;
    }
    if (cat.contains('school') || cat.contains('university')) {
      return AppColors.andreaBlue;
    }
    if (cat.contains('shop') ||
        cat.contains('market') ||
        cat.contains('siêu thị')) {
      return AppColors.chineseNewYear;
    }
    if (cat.contains('park') || cat.contains('công viên')) {
      return AppColors.aareRiver;
    }

    return AppColors.sMapTeal;
  }

  /// Màu nền nhẹ (badge) bọc icon
  static Color getBackgroundColor(String? category, {String? subCategory}) {
    return getIconColor(category, subCategory: subCategory).withAlpha(25);
  }

  /// Định dạng địa chỉ của POI an toàn, có fallback sang loại hình khi khuyết trường địa chỉ
  static String formatAddress(PoiModel poi) {
    if (poi.address != null && poi.address!.trim().isNotEmpty) {
      return poi.address!.trim();
    }

    final parts = [
      poi.housenumber,
      poi.street,
      poi.city,
    ]
        .where((part) => part != null && part.trim().isNotEmpty)
        .map((e) => e!.trim())
        .toList();

    if (parts.isNotEmpty) {
      return parts.join(', ');
    }

    // Fallback: nếu không có thông tin địa chỉ cụ thể, hiển thị subCategory hoặc category
    if (poi.subCategory != null && poi.subCategory!.trim().isNotEmpty) {
      return poi.subCategory!.trim();
    }
    if (poi.category != null && poi.category!.trim().isNotEmpty) {
      return poi.category!.trim();
    }

    return '';
  }

  /// Định dạng khoảng cách mét / kilomet thân thiện
  static String formatDistance(double distKm) {
    if (distKm < 1.0) {
      final meters = (distKm * 1000).round();
      return '$meters m';
    }
    return '${distKm.toStringAsFixed(1)} km';
  }

  /// Sắp xếp danh sách POI theo khoảng cách tăng dần từ vị trí GPS người dùng
  static List<PoiModel> sortPoisByDistance(
    List<PoiModel> pois,
    LatLng? userLocation,
  ) {
    if (userLocation == null || pois.length <= 1) {
      return pois;
    }
    final sorted = List<PoiModel>.from(pois);
    sorted.sort((a, b) {
      final distA = AppUtils.instance.calculateDistance(
        userLocation.latitude,
        userLocation.longitude,
        a.lat,
        a.lon,
      );
      final distB = AppUtils.instance.calculateDistance(
        userLocation.latitude,
        userLocation.longitude,
        b.lat,
        b.lon,
      );
      return distA.compareTo(distB);
    });
    return sorted;
  }

  /// Lấy khóa dịch i18n cho Category
  static String getCategoryLocaleKey(String? category) {
    final cat = (category ?? '').toLowerCase().trim();
    switch (cat) {
      case 'food':
      case 'restaurant':
        return LocaleKeys.category_food;
      case 'coffee':
      case 'cafe':
        return LocaleKeys.category_coffee;
      case 'hotel':
      case 'lodging':
        return LocaleKeys.category_hotel;
      case 'gas':
      case 'fuel':
        return LocaleKeys.category_gas;
      case 'atm':
      case 'bank':
        return LocaleKeys.category_atm;
      case 'hospital':
      case 'pharmacy':
        return LocaleKeys.category_hospital;
      default:
        return LocaleKeys.category_all;
    }
  }
}
