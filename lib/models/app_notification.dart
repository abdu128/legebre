import 'dart:convert';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    this.data = const <String, dynamic>{},
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is int
        ? rawId
        : rawId is String
        ? int.tryParse(rawId) ?? 0
        : 0;
    final title = json['title']?.toString() ?? '';
    final body = json['body']?.toString() ?? '';
    final isReadValue = json['is_read'] ?? json['isRead'];
    final data = _parseData(json['data']);
    final createdAt = _parseDate(json['created_at'] ?? json['createdAt']);
    final updatedAt = _parseDate(json['updated_at'] ?? json['updatedAt']);

    return AppNotification(
      id: id,
      title: title,
      body: body,
      isRead: _parseBool(isReadValue),
      data: data,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'body': body,
    'is_read': isRead,
    'data': data,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  static Map<String, dynamic> _parseData(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (_) {
        // Ignore malformed JSON payloads.
      }
    }
    return const <String, dynamic>{};
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.toLowerCase().trim();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      try {
        return DateTime.parse(value).toLocal();
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
