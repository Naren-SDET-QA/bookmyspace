import 'package:bookmyspace/features/admin/domain/listing_moderation.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('listing status infers published from verified active rows', () {
    final listing = ModeratedListing.fromJson({
      'id': 'v1',
      'name': 'Sunrise Function Hall',
      'latitude': 15.5,
      'longitude': 80.0,
      'is_active': true,
      'is_verified': true,
    });
    expect(listing.status, 'published');
    expect(listing.venue.resolvedListingStatus, 'published');
  });

  test('explicit listing_status wins over inferred flags', () {
    final listing = ModeratedListing.fromJson({
      'id': 'v2',
      'name': 'Draft Hall',
      'latitude': 0,
      'longitude': 0,
      'is_active': true,
      'is_verified': true,
      'listing_status': 'pending_approval',
      'listing_rejection_reason': '',
    });
    expect(listing.status, 'pending_approval');
  });

  test('venue copyWith preserves listing status', () {
    const venue = Venue(
      id: 'v',
      name: 'Hall',
      latitude: 0,
      longitude: 0,
      listingStatus: 'rejected',
      listingRejectionReason: 'Photos missing',
    );
    expect(venue.copyWith(name: 'Hall 2').listingStatus, 'rejected');
    expect(venue.resolvedListingStatus, 'rejected');
  });
}
