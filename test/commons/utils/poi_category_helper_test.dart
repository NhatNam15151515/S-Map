import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';

void main() {
  group('PoiCategoryHelper Tests', () {
    test('getIcon maps categories to expected IconData', () {
      expect(
        PoiCategoryHelper.getIcon('food'),
        equals(Icons.restaurant_rounded),
      );
      expect(
        PoiCategoryHelper.getIcon('coffee'),
        equals(Icons.coffee_rounded),
      );
      expect(
        PoiCategoryHelper.getIcon('hotel'),
        equals(Icons.hotel_rounded),
      );
      expect(
        PoiCategoryHelper.getIcon('gas'),
        equals(Icons.local_gas_station_rounded),
      );
      expect(
        PoiCategoryHelper.getIcon('atm'),
        equals(Icons.atm_rounded),
      );
      expect(
        PoiCategoryHelper.getIcon('hospital'),
        equals(Icons.local_hospital_rounded),
      );
      expect(
        PoiCategoryHelper.getIcon('unknown_category'),
        equals(Icons.place_rounded),
      );
      expect(
        PoiCategoryHelper.getIcon(null),
        equals(Icons.place_rounded),
      );
    });

    test('getIconColor maps categories to distinct colors', () {
      expect(
        PoiCategoryHelper.getIconColor('food'),
        equals(AppColors.sunOrange),
      );
      expect(
        PoiCategoryHelper.getIconColor('coffee'),
        equals(AppColors.burningTrail),
      );
      expect(
        PoiCategoryHelper.getIconColor('hotel'),
        equals(AppColors.googleBlue),
      );
      expect(
        PoiCategoryHelper.getIconColor('unknown'),
        equals(AppColors.sMapTeal),
      );
    });

    test('formatAddress formats address parts correctly', () {
      const poiWithFullAddress = PoiModel(
        name: 'Hồ Gươm',
        nameAscii: 'Ho Guom',
        lat: 21.0285,
        lon: 105.8542,
        address: 'Hàng Trống, Hoàn Kiếm, Hà Nội',
      );
      expect(
        PoiCategoryHelper.formatAddress(poiWithFullAddress),
        equals('Hàng Trống, Hoàn Kiếm, Hà Nội'),
      );

      const poiWithParts = PoiModel(
        name: 'Quán Cafe',
        nameAscii: 'Quan Cafe',
        lat: 21.0285,
        lon: 105.8542,
        housenumber: '12',
        street: 'Tràng Tiền',
        city: 'Hà Nội',
      );
      expect(
        PoiCategoryHelper.formatAddress(poiWithParts),
        equals('12, Tràng Tiền, Hà Nội'),
      );

      const poiEmpty = PoiModel(
        name: 'Điểm trống',
        nameAscii: 'Diem trong',
        lat: 0.0,
        lon: 0.0,
      );
      expect(
        PoiCategoryHelper.formatAddress(poiEmpty),
        isEmpty,
      );
    });

    test('getCategoryLocaleKey returns proper translation key', () {
      expect(
        PoiCategoryHelper.getCategoryLocaleKey('food'),
        equals(LocaleKeys.category_food),
      );
      expect(
        PoiCategoryHelper.getCategoryLocaleKey('coffee'),
        equals(LocaleKeys.category_coffee),
      );
      expect(
        PoiCategoryHelper.getCategoryLocaleKey('hotel'),
        equals(LocaleKeys.category_hotel),
      );
      expect(
        PoiCategoryHelper.getCategoryLocaleKey('unknown'),
        equals(LocaleKeys.category_all),
      );
    });
  });
}
