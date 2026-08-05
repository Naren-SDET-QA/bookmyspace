import 'package:bookmyspace/features/venue_import/domain/venue_claim_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = VenueClaimService();

  group('evidence validation', () {
    test('requires business name and phone', () {
      expect(
        () => service.validateEvidence(businessName: 'AB', contactPhone: '999'),
        throwsA(isA<VenueClaimValidationException>()),
      );
      expect(
        () => service.validateEvidence(
          businessName: 'ABC Halls',
          contactPhone: '123',
        ),
        throwsA(isA<VenueClaimValidationException>()),
      );
    });

    test('normalizes valid evidence', () {
      final e = service.validateEvidence(
        businessName: '  ABC   Halls ',
        contactPhone: '98765 43210',
        licenseId: 'GST123',
      );
      expect(e.businessName, 'ABC Halls');
      expect(e.contactPhone, '+919876543210');
      expect(e.toJson()['license_id'], 'GST123');
    });
  });

  group('claimable guards', () {
    test('blocks owner-verified and non-claimable', () {
      expect(
        () => service.assertClaimable(
          isClaimable: true,
          ownerVerified: true,
          hasPendingOtherClaim: false,
        ),
        throwsA(isA<VenueClaimValidationException>()),
      );
      expect(
        () => service.assertClaimable(
          isClaimable: false,
          ownerVerified: false,
          hasPendingOtherClaim: false,
        ),
        throwsA(isA<VenueClaimValidationException>()),
      );
      expect(
        () => service.assertClaimable(
          isClaimable: true,
          ownerVerified: false,
          hasPendingOtherClaim: true,
        ),
        throwsA(isA<VenueClaimValidationException>()),
      );
    });

    test('allows open claimable venue', () {
      expect(
        () => service.assertClaimable(
          isClaimable: true,
          ownerVerified: false,
          hasPendingOtherClaim: false,
        ),
        returnsNormally,
      );
    });
  });

  group('post-approval protection', () {
    test('approved flags mark owner_verified', () {
      final flags = service.approvedVenueFlags();
      expect(flags['owner_verified'], isTrue);
      expect(flags['is_claimable'], isFalse);
      expect(flags['owner_verified_fields'], isNotEmpty);
      expect(
        service.preventsImportOverwrite(
          ownerVerified: true,
          ownerVerifiedFields: const ['name'],
        ),
        isTrue,
      );
    });
  });
}
