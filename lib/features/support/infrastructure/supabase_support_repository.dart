import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../domain/support_ticket.dart';
import '../domain/support_ticket_repository.dart';

class SupabaseSupportRepository implements SupportTicketRepository {
  SupabaseSupportRepository(this._client);

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  @override
  Future<List<SupportTicket>> myTickets() async {
    try {
      final rows = await _client
          .from('support_tickets')
          .select('*')
          .eq('user_id', _userId!)
          .order('created_at', ascending: false);
      return rows.map((r) => SupportTicket.fromJson(r)).toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<SupportTicket> createTicket({
    required String subject,
    required String description,
    required String category,
    TicketPriority priority = TicketPriority.medium,
  }) async {
    try {
      final row = await _client
          .from('support_tickets')
          .insert({
            'user_id': _userId,
            'subject': subject,
            'description': description,
            'category': category,
            'priority': priority.dbValue,
          })
          .select('*')
          .single();
      return SupportTicket.fromJson(row);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<void> updateTicket({
    required String ticketId,
    String? subject,
    String? description,
    String? category,
    TicketPriority? priority,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (subject != null) updates['subject'] = subject;
      if (description != null) updates['description'] = description;
      if (category != null) updates['category'] = category;
      if (priority != null) updates['priority'] = priority.dbValue;
      await _client
          .from('support_tickets')
          .update(updates)
          .eq('id', ticketId)
          .eq('user_id', _userId!);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }
}