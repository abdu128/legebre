import 'dart:convert';

class FeedItem {
  const FeedItem({
    required this.id,
    required this.name,
    required this.status,
    this.price,
    this.feedType,
    this.animalType,
    this.brand,
    this.weight,
    this.unit,
    this.expiryDate,
    this.description,
    this.location,
    this.photos = const [],
    this.imageUrl,
    this.sellerName,
    this.sellerPhone,
    this.sellerWhatsapp,
    this.sellerId,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String name;
  final String status;
  final double? price;
  final String? feedType;
  final String? animalType;
  final String? brand;
  final double? weight;
  final String? unit;
  final DateTime? expiryDate;
  final String? description;
  final String? location;
  final List<String> photos;
  final String? imageUrl;
  final String? sellerName;
  final String? sellerPhone;
  final String? sellerWhatsapp;
  final int? sellerId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String? get primaryPhoto => photos.isNotEmpty ? photos.first : imageUrl;

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    int? parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    DateTime? parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    List<String> parsePhotos(dynamic value) {
      if (value is List) {
        return value
            .map((item) => item?.toString() ?? '')
            .where((url) => url.isNotEmpty)
            .toList();
      }
      if (value is String && value.isNotEmpty) {
        final trimmed = value.trim();
        if (trimmed.startsWith('[')) {
          try {
            final decoded = jsonDecode(trimmed);
            if (decoded is List) {
              return decoded
                  .map((item) => item?.toString() ?? '')
                  .where((url) => url.isNotEmpty)
                  .toList();
            }
          } catch (_) {
            // Ignore malformed JSON and fall back to plain string value.
          }
        }
        return [value];
      }
      return const [];
    }

    final photos = parsePhotos(json['photos']);
    final fallbackPhoto = json['photo']?.toString();

    return FeedItem(
      id: parseInt(json['id']) ?? 0,
      name:
          json['feedName']?.toString() ??
          json['name']?.toString() ??
          json['title']?.toString() ??
          'Feed item',
      status: (json['status'] ?? 'AVAILABLE').toString(),
      price: parseDouble(json['price']),
      feedType:
          json['feedType']?.toString() ??
          json['feed_type']?.toString() ??
          json['type']?.toString(),
      animalType:
          json['animalType']?.toString() ?? json['animal_type']?.toString(),
      brand: json['brand']?.toString(),
      weight: parseDouble(json['weight']),
      unit: json['unit']?.toString(),
      expiryDate: parseDate(json['expiryDate'] ?? json['expiry_date']),
      description: json['description']?.toString(),
      location: json['location']?.toString(),
      photos: photos,
      imageUrl: fallbackPhoto,
      sellerName: json['sellerName']?.toString(),
      sellerPhone: json['sellerPhone']?.toString(),
      sellerWhatsapp: json['sellerWhatsapp']?.toString(),
      sellerId: parseInt(json['sellerId']),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }
}
