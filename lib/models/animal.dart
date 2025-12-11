class Animal {
  const Animal({
    required this.id,
    required this.sellerId,
    required this.animalType,
    required this.status,
    required this.price,
    required this.photos,
    required this.createdAt,
    required this.updatedAt,
    this.breed,
    this.age,
    this.weight,
    this.description,
    this.location,
    this.verified = false,
    this.sellerName,
    this.sellerPhone,
    this.sellerWhatsapp,
    this.sellerVerified = false,
    this.isFavorite = false,
  });

  final int id;
  final int sellerId;
  final String animalType;
  final String status;
  final double price;
  final List<String> photos;
  final DateTime createdAt;
  final DateTime updatedAt;

  final String? breed;
  final String? age;
  final double? weight;
  final String? description;
  final String? location;
  final bool verified;

  final String? sellerName;
  final String? sellerPhone;
  final String? sellerWhatsapp;
  final bool sellerVerified;

  final bool isFavorite;

  String get coverPhoto => photos.firstWhere(
        (url) => url.isNotEmpty,
        orElse: () => 'https://placehold.co/600x400?text=No+photo',
      );

  Animal copyWith({
    bool? isFavorite,
  }) {
    return Animal(
      id: id,
      sellerId: sellerId,
      animalType: animalType,
      status: status,
      price: price,
      photos: photos,
      createdAt: createdAt,
      updatedAt: updatedAt,
      breed: breed,
      age: age,
      weight: weight,
      description: description,
      location: location,
      verified: verified,
      sellerName: sellerName,
      sellerPhone: sellerPhone,
      sellerWhatsapp: sellerWhatsapp,
      sellerVerified: sellerVerified,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  factory Animal.fromJson(Map<String, dynamic> json) {
    final photosList = (json['photos'] as List?)
            ?.map((item) => item?.toString())
            .whereType<String>()
            .where((url) => url.isNotEmpty)
            .toList() ??
        const <String>[];

    final priceValue = json['price'];
    double parsedPrice;
    if (priceValue is num) {
      parsedPrice = priceValue.toDouble();
    } else if (priceValue is String) {
      parsedPrice = double.tryParse(priceValue) ?? 0;
    } else {
      parsedPrice = 0;
    }

    final weightValue = json['weight'];
    double? parsedWeight;
    if (weightValue is num) {
      parsedWeight = weightValue.toDouble();
    } else if (weightValue is String) {
      parsedWeight = double.tryParse(weightValue);
    }

    return Animal(
      id: json['id'] as int,
      sellerId: json['seller_id'] as int? ?? json['sellerId'] as int? ?? 0,
      animalType: (json['animal_type'] ?? json['animalType'] ?? 'UNKNOWN')
          .toString()
          .toUpperCase(),
      status: (json['status'] ?? 'AVAILABLE').toString().toUpperCase(),
      price: parsedPrice,
      photos: photosList,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ??
          DateTime.tryParse(json['createdAt'] ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ??
          DateTime.tryParse(json['updatedAt'] ?? '') ??
          DateTime.now(),
      breed: json['breed']?.toString(),
      age: json['age']?.toString(),
      weight: parsedWeight,
      description: json['description']?.toString(),
      location: json['location']?.toString(),
      verified: json['verified'] as bool? ?? false,
      sellerName: json['seller_name']?.toString() ??
          json['sellerName']?.toString() ??
          json['seller']?['name']?.toString(),
      sellerPhone: json['seller_phone']?.toString() ??
          json['sellerPhone']?.toString() ??
          json['seller']?['phone']?.toString(),
      sellerWhatsapp: json['seller_whatsapp']?.toString() ??
          json['sellerWhatsapp']?.toString() ??
          json['seller']?['whatsapp']?.toString(),
      sellerVerified: json['seller_verified'] as bool? ??
          json['sellerVerified'] as bool? ??
          false,
      isFavorite: json['is_favorite'] as bool? ??
          json['isFavorite'] as bool? ??
          false,
    );
  }
}


