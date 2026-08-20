import 'package:flutter_test/flutter_test.dart';
import '../../../lib/features/registration/domain/module_registration.dart';
import '../../../lib/features/registration/domain/module_progress.dart';

void main() {
  test('feature configuration preserves server flags', () {
    final config = ModuleFeatureConfig.fromJson({
      'module_key': 'pg',
      'registration_enabled': true,
      'payment_enabled': true,
      'currency': 'INR',
    });
    expect(config.registrationEnabled, isTrue);
    expect(config.paymentEnabled, isTrue);
    expect(config.currency, 'INR');
  });

  test('form field types remain generic and serializable', () {
    final field = ModuleFormField(
      key: 'id_proof',
      label: 'ID proof',
      type: ModuleFieldType.idProof,
      required: true,
    );
    expect(field.toJson()['type'], 'idProof');
    expect(field.toJson()['required'], isTrue);
  });

  test(
    'module switches and payment policy are read from server configuration',
    () {
      final config = ModuleFeatureConfig.fromJson({
        'module_key': 'institutes',
        'documents_enabled': true,
        'payment_required_before_approval': true,
        'payment_required_before_confirmation': false,
        'payment_refundable': false,
        'map_enabled': false,
        'voice_enabled': true,
        'ai_help_enabled': true,
        'multilingual_enabled': true,
        'review_enabled': false,
      });
      expect(config.documentsEnabled, isTrue);
      expect(config.paymentRequiredBeforeApproval, isTrue);
      expect(config.paymentRefundable, isFalse);
      expect(config.mapEnabled, isFalse);
      expect(config.voiceEnabled, isTrue);
      expect(config.aiHelpEnabled, isTrue);
      expect(config.reviewEnabled, isFalse);
    },
  );

  test('document requirement preserves server validation metadata', () {
    final requirement = ModuleDocumentRequirement.fromJson({
      'id': 'req-1',
      'document_key': 'identity',
      'label': 'Identity document',
      'required': true,
      'allowed_mime_types': ['application/pdf', 'image/jpeg'],
      'max_size_bytes': 1000000,
    });
    expect(requirement.required, isTrue);
    expect(requirement.allowedMimeTypes, contains('application/pdf'));
    expect(requirement.maxSizeBytes, 1000000);
  });

  test('registration progress is configuration driven', () {
    final steps = moduleProgressSteps(
      ModuleFeatureConfig.fromJson({
        'module_key': 'pg',
        'documents_enabled': true,
        'payment_enabled': true,
        'approval_required': true,
      }),
    );
    expect(steps, contains(ModuleProgressStep.documents));
    expect(steps, contains(ModuleProgressStep.payment));
    expect(steps, contains(ModuleProgressStep.review));
    expect(steps, contains(ModuleProgressStep.approved));
  });

  test('disabled optional steps are omitted', () {
    final steps = moduleProgressSteps(
      ModuleFeatureConfig.fromJson({'module_key': 'enquiry'}),
    );
    expect(steps, [
      ModuleProgressStep.registration,
      ModuleProgressStep.completed,
    ]);
  });
}
