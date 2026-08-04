import 'package:bookmyspace/features/registration/domain/registration_form.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round trips reusable field configuration and stable ordering', () {
    const fields = [
      RegistrationFieldDefinition(
        key: 'consent',
        label: 'Consent',
        type: RegistrationFieldType.checkbox,
        order: 2,
        required: true,
        participantScope: RegistrationParticipantScope.all,
        collectionStage: RegistrationCollectionStage.checkIn,
        validation: {'pattern': 'true'},
      ),
      RegistrationFieldDefinition(
        key: 'email',
        label: 'Email',
        type: RegistrationFieldType.email,
        order: 1,
      ),
    ];
    final form = RegistrationFormDefinition.fromJson(
      {
        'id': 'form-id',
        'name': 'Guests',
        'module_key': 'any',
        'status': 'draft',
      },
      {
        'version': 3,
        'schema': {'fields': fields.map((f) => f.toJson()).toList()},
      },
    );

    expect(form.fields.map((f) => f.key), ['email', 'consent']);
    expect(form.fields.last.participantScope, RegistrationParticipantScope.all);
    expect(
      form.fields.last.collectionStage,
      RegistrationCollectionStage.checkIn,
    );
    expect(form.fields.last.required, isTrue);
    expect(form.schemaJson()['fields'], hasLength(2));
  });

  test('supports every shared field type', () {
    expect(
      RegistrationFieldType.values.map((e) => e.name),
      containsAll([
        'text',
        'number',
        'phone',
        'email',
        'date',
        'dropdown',
        'checkbox',
        'address',
        'photo',
        'file',
        'document',
        'custom',
      ]),
    );
    expect(
      RegistrationFormDefinition.stageKey(
        RegistrationCollectionStage.postBooking,
      ),
      'post_booking',
    );
  });
}
