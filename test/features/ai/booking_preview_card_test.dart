import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/ai/domain/booking_preview.dart';
import 'package:bookmyspace/features/ai/presentation/widgets/booking_preview_card.dart';

void main() {
  testWidgets('preview card shows server values and explicit actions', (tester) async {
    var confirmed = false;
    var changed = false;
    final preview = BookingPreview(
      venueId: 'v', venueName: 'Court 2', slotId: 's', date: 'Saturday',
      slotLabel: '6 PM', baseAmount: 500, taxAmount: 50, feeAmount: 0,
      discountAmount: 0, quantity: 1, totalAmount: 550,
      currency: 'INR', requiresConfirmation: true,
    );
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: BookingPreviewCard(
      preview: preview,
      submitting: false,
      onConfirm: () => confirmed = true,
      onChange: () => changed = true,
    ))));

    expect(find.text('Court 2'), findsOneWidget);
    expect(find.text('Total: INR 550.00'), findsOneWidget);
    await tester.tap(find.text('CONFIRM BOOKING'));
    await tester.tap(find.text('CHANGE'));
    expect(confirmed, isTrue);
    expect(changed, isTrue);
  });
}
