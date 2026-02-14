class FinancialInfo {
  const FinancialInfo({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.publisher,
    required this.createdAt,
    required this.updatedAt,
    this.attachmentUrl,
  });

  final int id;
  final String title;
  final String summary;
  final String content;
  final String publisher;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? attachmentUrl;

  factory FinancialInfo.fromJson(Map<String, dynamic> json) {
    int parseId() {
      final raw = json['id'] ?? json['info_id'];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw?.toString() ?? '') ?? 0;
    }

    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      final parsed = DateTime.tryParse(value?.toString() ?? '');
      return parsed ?? DateTime.now();
    }

    String readPublisher() {
      final raw = json['publisher'] ?? json['publisher_name'];
      final text = raw?.toString().trim();
      if (text == null || text.isEmpty) return 'Legebere Finance';
      return text;
    }

    return FinancialInfo(
      id: parseId(),
      title: json['title']?.toString() ?? 'Untitled',
      summary: json['summary']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      publisher: readPublisher(),
      attachmentUrl:
          json['attachment_url']?.toString() ??
          json['attachmentUrl']?.toString(),
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
      updatedAt: parseDate(json['updated_at'] ?? json['updatedAt']),
    );
  }
}
