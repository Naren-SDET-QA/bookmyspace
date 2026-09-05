import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/admin/domain/observability.dart';

void main() {
  test('health snapshots preserve verified status and response time', () {
    final item = HealthSnapshot.fromMap({'feature': 'API', 'status': 'healthy', 'response_ms': 42});
    expect(item.feature, 'API');
    expect(item.status, 'healthy');
    expect(item.responseMs, 42);
  });

  test('help articles expose language-ready content fields with safe fallbacks', () {
    final item = HelpArticle.fromMap({'id': '1', 'category': 'Booking', 'title': 'Booking help', 'summary': 'Steps'});
    expect(item.category, 'Booking');
    expect(item.content, isEmpty);
  });
}
