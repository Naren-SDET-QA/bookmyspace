import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/support_ticket.dart';
import '../domain/support_ticket_repository.dart';
import '../infrastructure/supabase_support_repository.dart';

final supportTicketRepositoryProvider = Provider<SupportTicketRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return SupabaseSupportRepository(client);
});

final myTicketsProvider = FutureProvider<List<SupportTicket>>((ref) {
  return ref.watch(supportTicketRepositoryProvider).myTickets();
});

final createTicketProvider = FutureProvider.autoDispose
    .family<SupportTicket, ({String subject, String description, String category, TicketPriority priority})>((
      ref,
      params,
    ) async {
      final repo = ref.watch(supportTicketRepositoryProvider);
      return repo.createTicket(
        subject: params.subject,
        description: params.description,
        category: params.category,
        priority: params.priority,
      );
    });

final updateTicketProvider = FutureProvider.autoDispose
    .family<void, ({String ticketId, String? subject, String? description, String? category, TicketPriority? priority})>((
      ref,
      params,
    ) async {
      final repo = ref.watch(supportTicketRepositoryProvider);
      await repo.updateTicket(
        ticketId: params.ticketId,
        subject: params.subject,
        description: params.description,
        category: params.category,
        priority: params.priority,
      );
      ref.invalidate(myTicketsProvider);
    });