import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/home/domain/context_aware_help.dart';
import 'package:bookmyspace/features/home/domain/customer_section_catalog.dart';

void main() {
  test('booking answer stays inside the selected hall section', () {
    final reply = ContextAwareHelp.answer(
      section: CustomerSection.functionHalls,
      question: 'book a hall in Hyderabad',
      location: 'Hyderabad',
    );
    expect(reply.action, HelpAction.booking);
    expect(reply.message, contains('live availability'));
  });

  test('institute booking requests become enquiry actions', () {
    final reply = ContextAwareHelp.answer(
      section: CustomerSection.institutesClasses,
      question: 'book a coaching class',
    );
    expect(reply.action, HelpAction.instituteEnquiry);
    expect(reply.message, contains('Call or WhatsApp'));
  });

  test('availability is never invented', () {
    final reply = ContextAwareHelp.answer(
      section: CustomerSection.pgHostels,
      question: 'is a bed available?',
    );
    expect(reply.action, HelpAction.search);
    expect(reply.message, contains('cannot promise'));
  });
}
