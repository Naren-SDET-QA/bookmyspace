import 'package:bookmyspace/features/registration/domain/registration_form.dart';
import 'package:bookmyspace/features/registration/presentation/widgets/dynamic_registration_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('registration form rejects invalid email in preview', (
    tester,
  ) async {
    final form = RegistrationFormDefinition.fromJson(
      {
        'id': 'form-id',
        'name': 'Guests',
        'module_key': 'any',
        'status': 'draft',
      },
      {
        'version': 1,
        'schema': {
          'fields': [
            const RegistrationFieldDefinition(
              key: 'email',
              label: 'Email',
              type: RegistrationFieldType.email,
              order: 1,
              required: true,
            ).toJson(),
          ],
        },
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DynamicRegistrationForm(
            definition: form,
            preview: true,
            onSubmit: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'bad');
    await tester.tap(find.text('Validate preview'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email'), findsOneWidget);
  });
}
