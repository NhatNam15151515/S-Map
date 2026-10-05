class PoiBounds {
  final double minLat;
  final double maxLat;
  final double minLon;
  final double maxLon;

  const PoiBounds({
    required this.minLat,
    required this.maxLat,
    required this.minLon,
    required this.maxLon,
  });

  @override
  String toString() =>
      'PoiBounds(lat: $minLat..$maxLat, lon: $minLon..$maxLon)';
}

class PoiModel {
  final int? id;
  final String? osmId;
  final String name;
  final String nameAscii;
  final String? category;
  final String? subCategory;
  final double lat;
  final double lon;
  final String? address;
  final String? street;
  final String? housenumber;
  final String? city;
  final int prominence;
  final String? provinceCode;
  final String? provinceLegacyCode;
  final String? districtCode;
  final int? streetId;
  final String? streetCore;
  final String? houseNo;
  final int? houseNoMain;
  final String? adminSource;
  final String? scope;

  const PoiModel({
    this.id,
    this.osmId,
    required this.name,
    required this.nameAscii,
    this.category,
    this.subCategory,
    required this.lat,
    required this.lon,
    this.address,
    this.street,
    this.housenumber,
    this.city,
    this.prominence = 0,
    this.provinceCode,
    this.provinceLegacyCode,
    this.districtCode,
    this.streetId,
    this.streetCore,
    this.houseNo,
    this.houseNoMain,
    this.adminSource,
    this.scope,
  });

  factory PoiModel.fromMap(Map<String, dynamic> map) {
    return PoiModel(
      id: map['id'] is int ? map['id'] as int : int.tryParse(map['id']?.toString() ?? ''),
      osmId: map['osm_id']?.toString(),
      name: map['name']?.toString() ?? '',
      nameAscii: map['name_ascii']?.toString() ?? '',
      category: map['category']?.toString(),
      subCategory: map['sub_category']?.toString(),
      lat: (map['lat'] as num?)?.toDouble() ?? 0.0,
      lon: (map['lon'] as num?)?.toDouble() ?? 0.0,
      address: map['address']?.toString(),
      street: map['street']?.toString(),
      housenumber: map['housenumber']?.toString(),
      city: map['city']?.toString(),
      prominence: (map['prominence'] as num?)?.toInt() ?? 0,
      provinceCode: map['province_code']?.toString(),
      provinceLegacyCode: map['province_legacy_code']?.toString(),
      districtCode: map['district_code']?.toString(),
      streetId: map['street_id'] is int
          ? map['street_id'] as int
          : int.tryParse(map['street_id']?.toString() ?? ''),
      streetCore: map['street_core']?.toString(),
      houseNo: map['house_no']?.toString(),
      houseNoMain: map['house_no_main'] is int
          ? map['house_no_main'] as int
          : int.tryParse(map['house_no_main']?.toString() ?? ''),
      adminSource: map['admin_source']?.toString(),
      scope: map['scope']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (osmId != null) 'osm_id': osmId,
      'name': name,
      'name_ascii': nameAscii,
      if (category != null) 'category': category,
      if (subCategory != null) 'sub_category': subCategory,
      'lat': lat,
      'lon': lon,
      if (address != null) 'address': address,
      if (street != null) 'street': street,
      if (housenumber != null) 'housenumber': housenumber,
      if (city != null) 'city': city,
      'prominence': prominence,
      if (provinceCode != null) 'province_code': provinceCode,
      if (provinceLegacyCode != null) 'province_legacy_code': provinceLegacyCode,
      if (districtCode != null) 'district_code': districtCode,
      if (streetId != null) 'street_id': streetId,
      if (streetCore != null) 'street_core': streetCore,
      if (houseNo != null) 'house_no': houseNo,
      if (houseNoMain != null) 'house_no_main': houseNoMain,
      if (adminSource != null) 'admin_source': adminSource,
      if (scope != null) 'scope': scope,
    };
  }

  /// Kiểm tra xem POI này và [other] có đại diện cho cùng một địa điểm hay không.
  ///
  /// Hai POI được coi là cùng một địa điểm nếu cùng toạ độ (lat/lon)
  /// và có cùng `id` hoặc `osmId` (nếu có thông tin định danh).
  bool isSamePoi(PoiModel? other) {
    if (other == null) return false;
    if (lat != other.lat || lon != other.lon) return false;
    if (id != null && other.id != null) {
      return id == other.id;
    }
    if (osmId != null && other.osmId != null) {
      return osmId == other.osmId;
    }
    return true;
  }

  @override
  String toString() =>
      'PoiModel(id: $id, name: $name, category: $category, lat: $lat, lon: $lon)';
}
