import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' show mapError;
import '../../venues/domain/venue.dart';
import '../domain/owner_listing_draft.dart';
import '../domain/owner_venue_repository.dart';

/// Supabase-backed [OwnerVenueRepository].
class SupabaseOwnerVenueRepository implements OwnerVenueRepository {
  SupabaseOwnerVenueRepository(this._client);

  final SupabaseClient _client;

  static const _hydrateSelect = '''
    *,
    venue_categories (id, slug, name, icon),
    venue_images (id, url, thumbnail_url, alt_text, is_cover, sort_order),
    venue_facilities (facility, is_available)
  ''';

  @override
  Future<List<Venue>> myVenues() async {
    try {
      final rows = await _client.rpc<List<dynamic>>('get_owner_venues');
      final ids = rows
          .whereType<Map<String, dynamic>>()
          .map((row) => row['id'] as String?)
          .whereType<String>()
          .toList();
      if (ids.isEmpty) return const [];
      return _hydrateByIds(ids);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<Venue> createVenue({
    required String name,
    required String categoryId,
    required String description,
    required String city,
    required String state,
    required double latitude,
    required double longitude,
    required int capacity,
    required double pricingBaseAmount,
  }) async {
    try {
      final data = await _client.rpc<Map<String, dynamic>>(
        'create_owner_venue',
        params: {
          'p_name': name,
          'p_category_id': categoryId,
          'p_description': description,
          'p_city': city,
          'p_state': state,
          'p_latitude': latitude,
          'p_longitude': longitude,
          'p_capacity': capacity,
          'p_pricing_base_amount': pricingBaseAmount,
        },
      );
      return Venue.fromJson(data);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<Venue> updateVenue({
    required String venueId,
    String? name,
    String? categoryId,
    String? description,
    String? city,
    String? state,
    double? latitude,
    double? longitude,
    int? capacity,
    double? pricingBaseAmount,
    bool? isActive,
  }) async {
    try {
      final data = await _client.rpc<Map<String, dynamic>>(
        'update_owner_venue',
        params: {
          'p_venue_id': venueId,
          if (name != null) 'p_name': name,
          if (categoryId != null) 'p_category_id': categoryId,
          if (description != null) 'p_description': description,
          if (city != null) 'p_city': city,
          if (state != null) 'p_state': state,
          if (latitude != null) 'p_latitude': latitude,
          if (longitude != null) 'p_longitude': longitude,
          if (capacity != null) 'p_capacity': capacity,
          if (pricingBaseAmount != null)
            'p_pricing_base_amount': pricingBaseAmount,
          if (isActive != null) 'p_is_active': isActive,
        },
      );
      return Venue.fromJson(data);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> deleteVenue(String venueId) async {
    try {
      await _client.rpc<void>(
        'delete_owner_venue',
        params: {'p_venue_id': venueId},
      );
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<Venue> saveListing({
    String? venueId,
    required OwnerListingDraft draft,
  }) async {
    try {
      draft.validate();
      Venue venue;
      if (venueId == null) {
        venue = await createVenue(
          name: draft.name,
          categoryId: draft.categoryId,
          description: draft.description,
          city: draft.city,
          state: draft.state,
          latitude: draft.latitude,
          longitude: draft.longitude,
          capacity: draft.capacity,
          pricingBaseAmount: draft.pricingBaseAmount,
        );
        if (!draft.publish) {
          venue = await updateVenue(venueId: venue.id, isActive: false);
        }
      } else {
        venue = await updateVenue(
          venueId: venueId,
          name: draft.name,
          categoryId: draft.categoryId,
          description: draft.description,
          city: draft.city,
          state: draft.state,
          latitude: draft.latitude,
          longitude: draft.longitude,
          capacity: draft.capacity,
          pricingBaseAmount: draft.pricingBaseAmount,
          isActive: draft.publish,
        );
      }

      await _patchAddress(venue.id, draft.addressLine1);
      final urls = <String>[];
      for (final photo in draft.photos) {
        if (photo.needsUpload) {
          urls.add(
            await uploadPhoto(
              venueId: venue.id,
              bytes: photo.bytes!,
              fileName: photo.fileName,
              contentType: photo.contentType,
            ),
          );
        } else if (photo.remoteUrl.trim().isNotEmpty) {
          urls.add(photo.remoteUrl.trim());
        }
      }
      await replaceImages(venue.id, urls);
      await replaceFacilities(venue.id, draft.facilities);
      final hydrated = await _hydrateByIds([venue.id]);
      return hydrated.isNotEmpty ? hydrated.first : venue;
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<Venue> setPublished(String venueId, bool published) async {
    try {
      await updateVenue(venueId: venueId, isActive: published);
      final hydrated = await _hydrateByIds([venueId]);
      if (hydrated.isEmpty) {
        throw StateError('Venue not found after publish update.');
      }
      return hydrated.first;
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<String> uploadPhoto({
    required String venueId,
    required List<int> bytes,
    required String fileName,
    String contentType = 'image/jpeg',
  }) async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) {
        throw StateError('Sign in as the owner to upload photos.');
      }
      if (!OwnerListingPhoto.allowedTypes.contains(contentType)) {
        throw StateError('Use JPG, PNG or WEBP photos.');
      }
      if (bytes.length > OwnerListingPhoto.maxBytes) {
        throw StateError('Each photo must be 5 MB or smaller.');
      }
      final rawName = fileName.trim().isEmpty ? 'photo.jpg' : fileName.trim();
      var safeName = rawName
          .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
          .toLowerCase();
      if (safeName.isEmpty || safeName == '_') {
        safeName = 'photo.jpg';
      }
      final path =
          '$uid/$venueId/${DateTime.now().microsecondsSinceEpoch}_$safeName';
      await _client.storage
          .from(OwnerListingDraft.storageBucket)
          .uploadBinary(
            path,
            bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
      return _client.storage
          .from(OwnerListingDraft.storageBucket)
          .getPublicUrl(path);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> replaceImages(String venueId, List<String> imageUrls) async {
    try {
      await _client.from('venue_images').delete().eq('venue_id', venueId);
      final urls = imageUrls
          .map((url) => url.trim())
          .where((url) => url.isNotEmpty)
          .take(OwnerListingDraft.maxPhotos)
          .toList();
      if (urls.isEmpty) return;
      await _client.from('venue_images').insert([
        for (var i = 0; i < urls.length; i++)
          {
            'venue_id': venueId,
            'url': urls[i],
            'alt_text': 'Photo ${i + 1}',
            'is_cover': i == 0,
            'sort_order': i,
          },
      ]);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> replaceFacilities(
    String venueId,
    List<String> facilities,
  ) async {
    try {
      await _client.from('venue_facilities').delete().eq('venue_id', venueId);
      final unique = <String>{};
      for (final raw in facilities) {
        final name = raw.trim();
        if (name.isNotEmpty) unique.add(name);
      }
      if (unique.isEmpty) return;
      await _client.from('venue_facilities').insert([
        for (final facility in unique)
          {'venue_id': venueId, 'facility': facility, 'is_available': true},
      ]);
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<void> _patchAddress(String venueId, String addressLine1) async {
    final address = addressLine1.trim();
    if (address.isEmpty) return;
    await _client
        .from('venues')
        .update({'address_line1': address})
        .eq('id', venueId);
  }

  Future<List<Venue>> _hydrateByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await _client
        .from('venues')
        .select(_hydrateSelect)
        .inFilter('id', ids);
    final byId = <String, Venue>{
      for (final row in rows)
        if (row['id'] is String) row['id'] as String: Venue.fromJson(row),
    };
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }
}
