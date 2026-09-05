import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/ai/domain/booking_preview.dart';

void main() {
  test(
    'booking preview preserves server-authoritative resource, slot and pricing',
    () {
      final preview = BookingPreview.fromActionResponse({
        'preview': {
          'venue': {'id': 'venue-1', 'name': 'Court 2'},
          'slot': {'id': 'slot-1', 'date': '2026-08-30', 'label': '6 PM'},
          'pricing': {
            'amount': 500,
            'tax_amount': 50,
            'total_amount': 550,
            'currency': 'INR',
          },
          'requires_confirmation': true,
        },
      });

      expect(preview.venueId, 'venue-1');
      expect(preview.slotId, 'slot-1');
      expect(preview.baseAmount, 500);
      expect(preview.taxAmount, 50);
      expect(preview.feeAmount, 0);
      expect(preview.discountAmount, 0);
      expect(preview.quantity, 1);
      expect(preview.totalAmount, 550);
      expect(preview.requiresConfirmation, isTrue);
    },
  );

  test('invalid preview response fails safely', () {
    expect(
      () => BookingPreview.fromActionResponse(const {}),
      throwsFormatException,
    );
  });
}
