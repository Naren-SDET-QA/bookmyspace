class HealthSnapshot {
  const HealthSnapshot({required this.feature, required this.status, this.responseMs});
  final String feature;
  final String status;
  final int? responseMs;
  factory HealthSnapshot.fromMap(Map<String, dynamic> map) => HealthSnapshot(
    feature: map['feature'] as String? ?? 'Unknown',
    status: map['status'] as String? ?? 'disabled',
    responseMs: (map['response_ms'] as num?)?.toInt(),
  );
}

class HelpArticle {
  const HelpArticle({required this.id, required this.category, required this.title, required this.summary, required this.content, this.language = 'en', this.enabled = true});
  final String id;
  final String category;
  final String title;
  final String summary;
  final String content;
  final String language;
  final bool enabled;
  factory HelpArticle.fromMap(Map<String, dynamic> map) => HelpArticle(
    id: map['id'] as String? ?? '',
    category: map['category'] as String? ?? 'General',
    title: map['title'] as String? ?? '',
    summary: map['summary'] as String? ?? '',
    content: map['steps'] as String? ?? '',
    language: map['language'] as String? ?? 'en',
    enabled: map['enabled'] != false,
  );
}
