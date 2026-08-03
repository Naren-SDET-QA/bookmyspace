import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../domain/event.dart';
import '../domain/event_repository.dart';

/// Supabase-backed [EventRepository].
///
/// * Lists and details come from the security-definer read functions
///   (`event_summaries` / `event_detail`) so live capacity counts and the
///   current user's registration state are computed server-side.
/// * Registration/cancellation go through the atomic RPCs which enforce
///   capacity under an advisory lock.
class SupabaseEventRepository implements EventRepository {
  SupabaseEventRepository(this._client);

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  @override
  Future<List<Event>> upcomingEvents() async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'event_summaries',
        params: {'p_user_id': _userId},
      );
      return rows
          .whereType<Map<String, dynamic>>()
          .map(Event.fromJson)
          .toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<Event> eventDetail(String eventId) async {
    try {
      final row = await _client
          .rpc<Map<String, dynamic>>(
            'event_detail',
            params: {'p_event_id': eventId, 'p_user_id': _userId},
          )
          .single();
      return Event.fromJson(row);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw const app_errors.NotFoundException(
          'Event not found',
          code: 'not_found',
        );
      }
      throw app_errors.mapError(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<EventRegistration> register({
    required String eventId,
    int quantity = 1,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw const app_errors.AuthException('You must be signed in.');
    }
    try {
      final id = await _client.rpc<String>(
        'register_for_event',
        params: {
          'p_event_id': eventId,
          'p_user_id': userId,
          'p_quantity': quantity,
        },
      );
      final row = await _client
          .from('event_registrations')
          .select('*')
          .eq('id', id)
          .single();
      return EventRegistration.fromResponse(row);
    } on PostgrestException catch (e) {
      throw _mapRpcError(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<void> cancelRegistration({required String eventId}) async {
    final userId = _userId;
    if (userId == null) {
      throw const app_errors.AuthException('You must be signed in.');
    }
    try {
      final row = await _client
          .from('event_registrations')
          .select('id')
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .eq('status', 'registered')
          .maybeSingle();
      if (row == null) {
        throw const app_errors.BusinessException(
          'No active registration to cancel.',
        );
      }
      await _client.rpc<void>(
        'cancel_event_registration',
        params: {'p_registration_id': row['id'], 'p_user_id': userId},
      );
    } on PostgrestException catch (e) {
      throw _mapRpcError(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  /// Maps RPC business errors to typed exceptions.
  app_errors.AppException _mapRpcError(PostgrestException e) {
    final message = e.message.toLowerCase();
    if (message.contains('event full')) {
      return const app_errors.BusinessException(
        'This event is sold out.',
        code: 'event_full',
      );
    }
    if (message.contains('event not available')) {
      return const app_errors.BusinessException(
        'This event is no longer available.',
        code: 'event_unavailable',
      );
    }
    return app_errors.mapError(e);
  }
}
