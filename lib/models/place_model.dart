class PlaceModel {
  final String? id;
  final String title;
  final String? subtitle;
  final String? category;
  final double? rating;
  final int? reviewCount;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;

  const PlaceModel({
    this.id,
    required this.title,
    this.subtitle,
    this.category,
    this.rating,
    this.reviewCount,
    this.latitude,
    this.longitude,
    this.imageUrl,
  });

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    return PlaceModel(
      id: json['id']?.toString(),
      title: json['title'] ?? '',
      subtitle: json['subtitle'],
      category: json['category'],
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      reviewCount: json['reviewCount'] as int?,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      imageUrl: json['imageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      if (category != null) 'category': category,
      if (rating != null) 'rating': rating,
      if (reviewCount != null) 'reviewCount': reviewCount,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (imageUrl != null) 'imageUrl': imageUrl,
    };
  }
}
