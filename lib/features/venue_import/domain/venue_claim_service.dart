import 'venue_import_normalizer.dart';

class VenueClaimEvidence {
  const VenueClaimEvidence({
    required this.businessName,
    required this.contactPhone,
    this.licenseId = '',
    this.notes = '',
  });

  final String businessName;
  final String contactPhone;
  final String licenseId;
  final String notes;

  Map<String, dynamic> toJson() => {
        'business_name': businessName.trim(),
        'contact_phone': contactPhone.trim(),
        if (licenseId.trim().isNotEmpty) 'license_id': licenseId.trim(),
        if (notes.trim().isNotEmpty) 'notes': notes.trim(),
      };
}

class VenueClaimValidationException implements Exception {
  VenueClaimValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Domain rules for Claim This Venue (owner verify → admin review).
class VenueClaimService {
  const VenueClaimService();

  /// Validates ownership evidence before submit (anti-fake).
  VenueClaimEvidence validateEvidence({
    required String businessName,
    required String contactPhone,
    String licenseId = '',
    String notes = '',
  }) {
    final name = businessName.trim().replaceAll(RegExp(r'\s+'), ' ');
    final phone = normalizeVenuePhone(contactPhone) ?? contactPhone.trim();
    if (name.length < 3) {
      throw VenueClaimValidationException('Business name is required');
    }
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      throw VenueClaimValidationException('Valid contact phone is required');
    }
    return VenueClaimEvidence(
      businessName: name,
      contactPhone: phone,
      licenseId: licenseId,
      notes: notes,
    );
  }

  /// Client-side guard before calling submit RPC.
  void assertClaimable({
    required bool isClaimable,
    required bool ownerVerified,
    required bool hasPendingOtherClaim,
  }) {
    if (ownerVerified) {
      throw VenueClaimValidationException('Venue is already owner-verified');
    }
    if (!isClaimable) {
      throw VenueClaimValidationException('Venue is not claimable');
    }
    if (hasPendingOtherClaim) {
      throw VenueClaimValidationException(
        'Another claim is already pending for this venue',
      );
    }
  }

  /// After admin approval, venue must be locked from import overwrite.
  Map<String, dynamic> approvedVenueFlags() => {
        'is_claimable': false,
        'is_verified': true,
        'owner_verified': true,
        'owner_verified_fields': ownerVerifiableFields,
      };

  bool preventsImportOverwrite({
    required bool ownerVerified,
    required List<String> ownerVerifiedFields,
  }) =>
      ownerVerified || ownerVerifiedFields.isNotEmpty;
}
