import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/owner/domain/registration_field_config.dart';

void main() {
  test('maps configured field types and visibility', () {
    final field = RegistrationFieldConfig.fromJson({
      'field_key': 'pan',
      'display_label': 'PAN',
      'field_type': 'document_upload',
      'enabled': true,
      'required': true,
      'owner_visible': true,
      'customer_visible': false,
      'admin_only': false,
      'sensitive': true,
      'placeholder': 'Upload document',
      'help_text': 'Private verification document',
    });

    expect(field.type, RegistrationFieldType.documentUpload);
    expect(field.sensitive, isTrue);
    expect(field.customerVisible, isFalse);
    expect(field.ownerVisible, isTrue);
  });

  test('unknown field type safely falls back to text', () {
    final field = RegistrationFieldConfig.fromJson({
      'field_key': 'custom',
      'display_label': 'Custom',
      'field_type': 'future_type',
    });
    expect(field.type, RegistrationFieldType.text);
  });

  test('admin dropdown options are read from validation rules', () {
    final field = RegistrationFieldConfig.fromJson({
      'field_key': 'business_type',
      'display_label': 'Business type',
      'field_type': 'dropdown',
      'required': true,
      'validation_rules': {
        'options': ['Hall', 'Lodge', 'PG'],
      },
    });

    expect(field.options, ['Hall', 'Lodge', 'PG']);
    expect(field.required, isTrue);
  });
}
