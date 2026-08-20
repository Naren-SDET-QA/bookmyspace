import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/business/domain/pricing_feature.dart';

void main() {
  test('parses versioned minor-unit pricing without floating point', () {
    final feature = PricingFeature.fromJson({
      'feature_key': 'PHONE_REVEAL',
      'name': 'Reveal phone',
      'amount_minor': 1000,
      'currency': 'INR',
      'pricing_model': 'pay_per_view',
      'version': 2,
      'is_active': true,
    });

    expect(feature.amountMinor, 1000);
    expect(feature.pricingModel, PricingModel.payPerView);
    expect(feature.version, 2);
  });

  test('unknown pricing model defaults safely', () {
    final feature = PricingFeature.fromJson({
      'feature_key': 'CUSTOM',
      'name': 'Custom',
      'amount_minor': 0,
      'pricing_model': 'unknown',
    });
    expect(feature.pricingModel, PricingModel.oneTime);
  });
}
