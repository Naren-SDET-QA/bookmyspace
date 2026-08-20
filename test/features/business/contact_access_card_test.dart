import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/business/domain/pricing_feature.dart';
import 'package:bookmyspace/features/business/presentation/widgets/contact_access_card.dart';

void main() {
  testWidgets('shows configured price and does not expose contact initially',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ContactAccessCard(
        label: 'Phone',
        feature: const PricingFeature(
          featureKey: 'PHONE_REVEAL',
          name: 'Phone',
          amountMinor: 1000,
          currency: 'INR',
          pricingModel: PricingModel.payPerView,
          version: 1,
        ),
        onPurchase: () async {},
        onReveal: () async => '+91 9876543210',
      ),
    ));
    expect(find.textContaining('Reveal'), findsOneWidget);
    expect(find.text('+91 9876543210'), findsNothing);
  });
}
