import 'package:bookmyspace/features/support/domain/support_ticket.dart';
import 'package:bookmyspace/features/support/domain/support_ticket_repository.dart';

class MockSupportRepository implements SupportTicketRepository {
  final List<SupportTicket> tickets = [];
  ({String subject, String description})? lastCreate;

  @override
  Future<SupportTicket> createTicket({
    required String subject,
    required String description,
    required String category,
    TicketPriority priority = TicketPriority.medium,
  }) async {
    lastCreate = (subject: subject, description: description);
    final ticket = SupportTicket(
      id: 't-${tickets.length + 1}',
      userId: 'u-test',
      subject: subject,
      description: description,
      category: category,
      priority: priority,
      status: TicketStatus.open,
      createdAt: DateTime.now(),
    );
    tickets.add(ticket);
    return ticket;
  }

  @override
  Future<List<SupportTicket>> myTickets() async => tickets;

  @override
  Future<void> updateTicket({
    required String ticketId,
    String? subject,
    String? description,
    String? category,
    TicketPriority? priority,
  }) async {}
}
