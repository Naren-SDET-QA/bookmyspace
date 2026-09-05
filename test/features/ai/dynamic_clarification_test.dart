import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/ai/domain/dynamic_clarification.dart';

void main() {
  test('dynamic schema preserves configured field types and required flags', () {
    final schema = DynamicFieldSchema.fromMetadata({
      'fields': [
        {'key': 'court_type', 'label': 'Court type', 'type': 'DROPDOWN', 'required': true, 'options': ['Indoor', 'Outdoor']},
        {'key': 'players', 'label': 'Players', 'type': 'NUMBER', 'required': false},
      ],
    });
    expect(schema.fields.map((field) => field.key), ['court_type', 'players']);
    expect(schema.fields.first.type, DynamicFieldType.dropdown);
    expect(schema.fields.first.options, ['Indoor', 'Outdoor']);
    expect(schema.requiredKeys, ['court_type']);
  });

  test('clarification state merges answers and reports only remaining fields', () {
    final state = ClarificationState.create(userId: 'u1', sessionId: 's1', categorySlug: 'sports_court', requiredFields: const ['court_type', 'date'])
        .answer('court_type', 'Indoor');
    expect(state.missingFields, ['date']);
    expect(state.answer('date', '2026-08-28').missingFields, isEmpty);
  });

  test('clarification state rejects wrong user and expires safely', () {
    final state = ClarificationState.create(userId: 'u1', sessionId: 's1', categorySlug: 'future', requiredFields: const ['date'], now: DateTime(2026, 1, 1), ttl: const Duration(minutes: 5));
    expect(() => state.forUser('u2'), throwsStateError);
    expect(state.isExpired(DateTime(2026, 1, 1, 0, 6)), isTrue);
  });
}
