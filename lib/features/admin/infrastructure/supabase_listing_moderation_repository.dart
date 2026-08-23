import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' show mapError;
import '../domain/listing_moderation.dart';
import '../domain/listing_moderation_repository.dart';

class SupabaseListingModerationRepository
    implements ListingModerationRepository, ListingLifecycleRepository {
  SupabaseListingModerationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ModeratedListing>> listings({String? status}) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'admin_list_listings',
        params: {'p_status': status},
      );
      return rows
          .whereType<Map<String, dynamic>>()
          .map(ModeratedListing.fromJson)
          .toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<ModeratedListing> moderate({
    required String venueId,
    required String action,
    String? reason,
  }) async {
    try {
      final row = await _client.rpc<Map<String, dynamic>>(
        'admin_moderate_listing',
        params: {'p_venue_id': venueId, 'p_action': action, 'p_reason': reason},
      );
      return ModeratedListing.fromJson(row);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<ModeratedListing> submitForReview(String venueId) async {
    try {
      final row = await _client.rpc<Map<String, dynamic>>(
        'submit_listing_for_review',
        params: {'p_venue_id': venueId},
      );
      return ModeratedListing.fromJson(row);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<List<OversightRow>> bookings({int limit = 50}) async {
    try {
      final rows = await _client
          .from('bookings')
          .select('id, status, total_amount, created_at, venues(name)')
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.whereType<Map<String, dynamic>>().map((row) {
        final venue = row['venues'];
        final name = venue is Map ? venue['name']?.toString() ?? '' : '';
        return OversightRow(
          id: row['id'] as String? ?? '',
          title: name.isEmpty ? 'Booking' : name,
          subtitle: (row['id'] as String? ?? '').substring(0, 8),
          status: row['status'] as String? ?? '',
          amount: (row['total_amount'] as num?)?.toDouble(),
          createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
        );
      }).toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<List<OversightRow>> payments({int limit = 50}) async {
    try {
      final rows = await _client
          .from('payments')
          .select('id, status, amount, currency, created_at, booking_id')
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.whereType<Map<String, dynamic>>().map((row) {
        return OversightRow(
          id: row['id'] as String? ?? '',
          title: 'Payment ${row['currency'] ?? 'INR'}',
          subtitle: row['booking_id'] as String? ?? '',
          status: row['status'] as String? ?? '',
          amount: (row['amount'] as num?)?.toDouble(),
          createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
        );
      }).toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<List<OversightRow>> refunds({int limit = 50}) async {
    try {
      final rows = await _client
          .from('refunds')
          .select('id, status, amount, created_at, payment_id')
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.whereType<Map<String, dynamic>>().map((row) {
        return OversightRow(
          id: row['id'] as String? ?? '',
          title: 'Refund',
          subtitle: row['payment_id'] as String? ?? '',
          status: row['status'] as String? ?? '',
          amount: (row['amount'] as num?)?.toDouble(),
          createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
        );
      }).toList();
    } catch (e) {
      throw mapError(e);
    }
  }
}
