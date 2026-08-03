import '../domain/support_ticket.dart';

abstract interface class SupportTicketRepository {
  Future<List<SupportTicket>> myTickets();
  Future<SupportTicket> createTicket({
    required String subject,
    required String description,
    required String category,
    TicketPriority priority = TicketPriority.medium,
  });
  Future<void> updateTicket({
    required String ticketId,
    String? subject,
    String? description,
    String? category,
    TicketPriority? priority,
  });
}