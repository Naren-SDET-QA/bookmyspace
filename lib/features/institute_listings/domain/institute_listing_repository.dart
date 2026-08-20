import 'package:bookmyspace/features/institute_listings/domain/institute_listing.dart';

abstract class InstituteListingRepository {
  Future<InstituteListing?> getActiveListingForInstitute(String instituteId);
  Future<InstituteListing> createListing({
    required String instituteId,
    required String planId,
  });
  Future<void> updateListing(String id, {String? paymentId, bool? isActive});
}
