class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.role,
    this.email,
    this.phone,
    this.whatsapp,
    this.profilePhoto,
    this.verified = false,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String name;
  final String role;
  final String? email;
  final String? phone;
  final String? whatsapp;
  final String? profilePhoto;
  final bool verified;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayPhone => phone ?? whatsapp ?? '';

  factory AppUser.fromJson(Map<String, dynamic> json) {
    String? readName() {
      final candidates = [
        json['name'],
        json['full_name'],
        json['fullName'],
        json['displayName'],
      ];
      for (final value in candidates) {
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return null;
    }

    String? readPhone() {
      final candidates = [
        json['phone'],
        json['phone_number'],
        json['phoneNumber'],
        json['contactPhone'],
      ];
      for (final value in candidates) {
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return null;
    }

    String? readWhatsapp() {
      final candidates = [
        json['whatsapp'],
        json['whatsapp_number'],
        json['whatsappNumber'],
        json['contactWhatsapp'],
      ];
      for (final value in candidates) {
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return null;
    }

    int parseId() {
      final candidates = [json['id'], json['user_id'], json['userId']];
      for (final value in candidates) {
        if (value == null) continue;
        if (value is int) return value;
        if (value is num) return value.toInt();
        if (value is String) {
          final parsed = int.tryParse(value);
          if (parsed != null) return parsed;
        }
      }
      return 0;
    }

    return AppUser(
      id: parseId(),
      name: readName() ?? 'Unnamed',
      role: json['role']?.toString() ?? 'BUYER',
      email: json['email']?.toString(),
      phone: readPhone(),
      whatsapp: readWhatsapp(),
      profilePhoto:
          json['profile_photo']?.toString() ?? json['photoUrl']?.toString(),
      verified: json['verified'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['created_at'] ?? '') ??
          DateTime.tryParse(json['createdAt'] ?? ''),
      updatedAt:
          DateTime.tryParse(json['updated_at'] ?? '') ??
          DateTime.tryParse(json['updatedAt'] ?? ''),
    );
  }

  AppUser copyWith({
    String? name,
    String? email,
    String? phone,
    String? whatsapp,
    String? profilePhoto,
    bool? verified,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      role: role,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      verified: verified ?? this.verified,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
