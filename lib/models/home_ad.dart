class HomeAd {
  const HomeAd({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.targetType,
    this.subtitle,
    this.targetId,
    this.externalUrl,
    this.placement = 'HOME_BOTH',
    this.priority = 0,
    this.isActive = true,
    this.startAt,
    this.endAt,
  });

  final int id;
  final String title;
  final String? subtitle;
  final String imageUrl;
  final String targetType;
  final int? targetId;
  final String? externalUrl;
  final String placement;
  final int priority;
  final bool isActive;
  final DateTime? startAt;
  final DateTime? endAt;

  bool get showOnTop => placement == 'HOME_TOP' || placement == 'HOME_BOTH';
  bool get showOnMid => placement == 'HOME_MID' || placement == 'HOME_BOTH';

  factory HomeAd.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    int? parseNullableInt(dynamic value) {
      if (value == null) return null;
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

    return HomeAd(
      id: parseInt(json['id']),
      title: (json['title'] ?? '').toString(),
      subtitle: json['subtitle']?.toString(),
      imageUrl: (json['image_url'] ?? json['imageUrl'] ?? '').toString(),
      targetType: (json['target_type'] ?? json['targetType'] ?? '')
          .toString()
          .toUpperCase(),
      targetId: parseNullableInt(json['target_id'] ?? json['targetId']),
      externalUrl:
          json['external_url']?.toString() ?? json['externalUrl']?.toString(),
      placement: (json['placement'] ?? 'HOME_BOTH').toString().toUpperCase(),
      priority: parseInt(json['priority']),
      isActive: json['is_active'] as bool? ?? json['isActive'] as bool? ?? true,
      startAt: parseDate(json['start_at'] ?? json['startAt']),
      endAt: parseDate(json['end_at'] ?? json['endAt']),
    );
  }
}
