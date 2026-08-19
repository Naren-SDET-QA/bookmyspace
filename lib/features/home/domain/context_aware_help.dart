import 'customer_section_catalog.dart';

enum HelpAction { search, booking, instituteEnquiry }

class ContextAwareHelpReply {
  const ContextAwareHelpReply({required this.message, this.action});

  final String message;
  final HelpAction? action;
}

/// Local, safe fallback for ContextAwareHelp. A remote AI can be added behind
/// this boundary later without allowing it to invent availability or bypass
/// the normal booking flow.
class ContextAwareHelp {
  static ContextAwareHelpReply answer({
    required CustomerSection? section,
    required String question,
    String? location,
  }) {
    final text = question.trim().toLowerCase();
    final place = location == null || location.trim().isEmpty
        ? ''
        : ' near ${location.trim()}';
    if (section == null) {
      return const ContextAwareHelpReply(
        message: 'Choose Halls, Lodge, PG or Institutes first so I can help.',
      );
    }
    if (text.isEmpty) {
      return ContextAwareHelpReply(
        message: 'Ask about ${section.title.toLowerCase()} search, location, availability or booking.',
      );
    }
    if (section == CustomerSection.institutesClasses) {
      if (_asksBooking(text)) {
        return const ContextAwareHelpReply(
          message: 'Institutes and classes are listing-only. Open the listing to Call or WhatsApp the institute.',
          action: HelpAction.instituteEnquiry,
        );
      }
      return ContextAwareHelpReply(
        message: 'I can help find institute listings$place by course, category and online/offline mode. Availability and fees must be confirmed with the institute.',
        action: HelpAction.search,
      );
    }
    if (_asksBooking(text)) {
      return const ContextAwareHelpReply(
        message: 'I will open the normal booking flow. It will re-check live availability and price before payment.',
        action: HelpAction.booking,
      );
    }
    if (_asksAvailability(text)) {
      return const ContextAwareHelpReply(
        message: 'Availability is confirmed only by the live slot search and booking flow; I cannot promise a slot from chat.',
        action: HelpAction.search,
      );
    }
    return ContextAwareHelpReply(
      message: 'I can help search ${section.title.toLowerCase()}$place by category and filters. Try “find available options” or “book this”.',
      action: HelpAction.search,
    );
  }

  static bool _asksBooking(String text) =>
      text.contains('book') || text.contains('reserve') || text.contains('రుసర్వ్');

  static bool _asksAvailability(String text) =>
      text.contains('available') || text.contains('availability') || text.contains('ఖాళీ');
}
