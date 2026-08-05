import 'package:bookmyspace/features/venue_import/domain/venue_import_models.dart';
import 'package:bookmyspace/features/venue_import/domain/venue_staging_review.dart';
import 'package:flutter_test/flutter_test.dart';

VenueImportStagingRow _row({
  String id = 's1',
  String name = 'ABC Function Hall',
  VenueImportStagingStatus status = VenueImportStagingStatus.pendingReview,
  String sourcePlaceId = 'osm:100',
  String source = 'osm',
  double lat = 15.5,
  double lng = 80.0,
}) {
  return VenueImportStagingRow(
    id: id,
    jobId: 'job1',
    name: name,
    categorySlug: 'function_hall',
    status: status,
    addressLine1: 'MG Road',
    city: 'Ongole',
    state: 'Andhra Pradesh',
    phone: '9876543210',
    latitude: lat,
    longitude: lng,
    source: source,
    sourcePlaceId: sourcePlaceId,
    fetchedAt: DateTime.utc(2026, 8, 4),
  );
}

void main() {
  const review = VenueStagingReviewService();

  group('preview edit', () {
    test('normalizes fields and locks provenance', () {
      final edited = review.applyPreviewEdits(
        row: _row(),
        name: '  New   Hall ',
        addressLine1: '  Trunk   Road ',
        phone: '99999 88888',
        website: ' https://example.com ',
      );
      expect(edited.name, 'New Hall');
      expect(edited.addressLine1, 'Trunk Road');
      expect(edited.phone, '+919999988888');
      expect(edited.website, 'https://example.com');
      expect(edited.source, 'osm');
      expect(edited.sourcePlaceId, 'osm:100');
      expect(edited.fetchedAt, DateTime.utc(2026, 8, 4));
    });

    test('rejects empty name and published edits', () {
      expect(
        () => review.applyPreviewEdits(row: _row(), name: '  '),
        throwsA(isA<StagingReviewException>()),
      );
      expect(
        () => review.applyPreviewEdits(
          row: _row(status: VenueImportStagingStatus.published),
          name: 'X',
        ),
        throwsA(isA<StagingReviewException>()),
      );
    });
  });

  group('approve / reject / publish', () {
    test('approve then publish happy path', () {
      final approved = review.approve(_row());
      expect(approved.status, VenueImportStagingStatus.approved);
      final published = review.preparePublish(
        row: approved,
        published: const [],
        newVenueId: 'v-new',
      );
      expect(published.status, VenueImportStagingStatus.published);
      expect(published.publishedVenueId, 'v-new');
    });

    test('reject path', () {
      final rejected = review.reject(_row());
      expect(rejected.status, VenueImportStagingStatus.rejected);
      expect(
        () => review.preparePublish(row: rejected, published: const []),
        throwsA(isA<StagingReviewException>()),
      );
    });

    test('never overwrite owner-verified duplicate', () {
      final approved = review.approve(_row());
      expect(
        () => review.preparePublish(
          row: approved,
          published: const [
            PublishedVenueGuard(
              id: 'v-owned',
              name: 'ABC Function Hall',
              latitude: 15.5,
              longitude: 80.0,
              source: 'osm',
              sourcePlaceId: 'osm:100',
              ownerVerified: true,
            ),
          ],
        ),
        throwsA(isA<OwnerVerifiedProtectionException>()),
      );
    });

    test('dedupe match without owner_verified can publish to existing id', () {
      final approved = review.approve(_row(name: 'Other Name'));
      final published = review.preparePublish(
        row: approved,
        published: const [
          PublishedVenueGuard(
            id: 'v-existing',
            name: 'Different',
            latitude: 1,
            longitude: 1,
            source: 'osm',
            sourcePlaceId: 'osm:100',
            ownerVerified: false,
          ),
        ],
      );
      expect(published.publishedVenueId, 'v-existing');
      expect(published.status, VenueImportStagingStatus.published);
    });

    test('provenance map retained', () {
      final p = review.provenanceOf(_row());
      expect(p['source'], 'osm');
      expect(p['source_place_id'], 'osm:100');
      expect(p['category_slug'], 'function_hall');
      expect(p['fetched_at'], isNotNull);
    });
  });
}
