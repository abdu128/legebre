class VetDrug {
  const VetDrug({
    required this.id,
    required this.name,
    this.description,
    this.price,
    this.status,
    this.imageUrl,
    this.category,
    this.unit,
    this.stock,
    this.manufacturer,
    this.usage,
    this.dosage,
    this.storage,
    this.sellerName,
    this.contactPhone,
    this.contactWhatsapp,
    this.deliveryRegions,
    this.sellerId,
    this.photos = const [],
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String name;
  final String? description;
  final double? price;
  final String? status;
  final String? imageUrl;
  final String? category;
  final String? unit;
  final int? stock;
  final String? manufacturer;
  final String? usage;
  final String? dosage;
  final String? storage;
  final String? sellerName;
  final String? contactPhone;
  final String? contactWhatsapp;
  final String? deliveryRegions;
  final int? sellerId;
  final List<String> photos;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String? get primaryPhoto => photos.isNotEmpty ? photos.first : imageUrl;

  factory VetDrug.fromJson(Map<String, dynamic> json) {
    double? parsedPrice;
    final priceValue = json['price'];
    if (priceValue is num) {
      parsedPrice = priceValue.toDouble();
    } else if (priceValue is String) {
      parsedPrice = double.tryParse(priceValue);
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
            .map((item) => item == null ? '' : item.toString())
            .where((url) => url.isNotEmpty)
            .toList();
      }
      if (value is String && value.isNotEmpty) return [value];
      return const [];
    }

    final photos = parsePhotos(json['photos']);
    final primaryPhoto = photos.isNotEmpty
        ? photos.first
        : json['photo']?.toString();

    return VetDrug(
      id: parseInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? 'Vet drug',
      description: json['description']?.toString(),
      price: parsedPrice,
      status: json['status']?.toString(),
      imageUrl: primaryPhoto,
      category: json['category']?.toString(),
      unit: json['unit']?.toString(),
      stock: parseInt(json['stock'] ?? json['quantity']),
      manufacturer: json['manufacturer']?.toString(),
      usage: json['usage']?.toString() ?? json['instructions']?.toString(),
      dosage: json['dosage']?.toString(),
      storage: json['storage']?.toString(),
      sellerName:
          json['sellerName']?.toString() ?? json['pharmacist']?.toString(),
      contactPhone:
          json['contactPhone']?.toString() ?? json['phone']?.toString(),
      contactWhatsapp:
          json['contactWhatsapp']?.toString() ?? json['whatsapp']?.toString(),
      deliveryRegions:
          json['deliveryRegions']?.toString() ??
          json['deliveryArea']?.toString(),
      sellerId: parseInt(json['sellerId'] ?? json['seller_id']),
      photos: photos,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }
}
