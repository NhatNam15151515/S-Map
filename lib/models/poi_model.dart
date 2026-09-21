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
