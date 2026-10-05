class StreetModel {
  final int id;
  final String provinceCode;
  final String? districtCode;
  final String name;
  final String nameCore;
  final int poiCount;
  final int houseCount;
  final double centerLat;
  final double centerLon;
  final double? minLat;
  final double? maxLat;
  final double? minLon;
  final double? maxLon;

  const StreetModel({
    required this.id,
    required this.provinceCode,
    this.districtCode,
    required this.name,
    required this.nameCore,
    this.poiCount = 0,
    this.houseCount = 0,
    required this.centerLat,
    required this.centerLon,
    this.minLat,
    this.maxLat,
    this.minLon,
    this.maxLon,
  });

  factory StreetModel.fromMap(Map<String, dynamic> map) {
    return StreetModel(
      id: (map['id'] as num?)?.toInt() ?? 0,
      provinceCode: map['province_code']?.toString() ?? '',
      districtCode: map['district_code']?.toString(),
      name: map['name']?.toString() ?? '',
      nameCore: map['name_core']?.toString() ?? '',
      poiCount: (map['poi_count'] as num?)?.toInt() ?? 0,
      houseCount: (map['house_count'] as num?)?.toInt() ?? 0,
      centerLat: (map['center_lat'] as num?)?.toDouble() ?? 0.0,
      centerLon: (map['center_lon'] as num?)?.toDouble() ?? 0.0,
      minLat: (map['min_lat'] as num?)?.toDouble(),
      maxLat: (map['max_lat'] as num?)?.toDouble(),
      minLon: (map['min_lon'] as num?)?.toDouble(),
      maxLon: (map['max_lon'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'province_code': provinceCode,
      if (districtCode != null) 'district_code': districtCode,
      'name': name,
      'name_core': nameCore,
      'poi_count': poiCount,
      'house_count': houseCount,
      'center_lat': centerLat,
      'center_lon': centerLon,
      if (minLat != null) 'min_lat': minLat,
      if (maxLat != null) 'max_lat': maxLat,
      if (minLon != null) 'min_lon': minLon,
      if (maxLon != null) 'max_lon': maxLon,
    };
  }

  @override
  String toString() => 'StreetModel(id: $id, name: $name, prov: $provinceCode)';
}
