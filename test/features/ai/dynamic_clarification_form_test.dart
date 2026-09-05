import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/ai/domain/dynamic_clarification.dart';
import 'package:bookmyspace/features/ai/presentation/widgets/dynamic_clarification_form.dart';

void main() {
  testWidgets('renders configured fields and conditional fields only when active', (tester) async {
    final schema = DynamicFieldSchema.fromMetadata({'fields': [
      {'key': 'booking_type', 'label': 'Booking type', 'type': 'dropdown', 'required': true, 'options': ['online', 'onsite']},
      {'key': 'meeting_type', 'label': 'Meeting type', 'type': 'text', 'when': {'field': 'booking_type', 'equals': 'online'}},
    ]});
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DynamicClarificationForm(schema: schema, values: const {'booking_type': 'onsite'}, onChanged: (_) {}))));
    expect(find.text('Booking type'), findsOneWidget);
    expect(find.text('Meeting type'), findsNothing);
  });
}
