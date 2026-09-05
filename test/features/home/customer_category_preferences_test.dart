import 'package:flutter_test/flutter_test.dart';

import 'package:bookmyspace/features/home/domain/customer_category_preferences.dart';

void main() {
  test('defaults keep all configured sections visible', () {
    final prefs = CustomerCategoryPreferences.defaults(['hotels', 'pg']);
    expect(prefs.visibleIds, ['hotels', 'pg']);
  });

  test('only selected categories remain visible in display order', () {
    final prefs = CustomerCategoryPreferences.fromEnabled(
      ['hotels', 'pg', 'marriage_halls'],
      const {'pg': false, 'hotels': true, 'marriage_halls': true},
    );
    expect(prefs.visibleIds, ['hotels', 'marriage_halls']);
  });

  test('all disabled falls back to the first configured category', () {
    final prefs = CustomerCategoryPreferences.fromEnabled(
      ['hotels', 'pg'],
      const {'hotels': false, 'pg': false},
    );
    expect(prefs.visibleIds, ['hotels']);
  });

  test('unknown configured categories remain supported', () {
    final prefs = CustomerCategoryPreferences.defaults(['coworking']);
    expect(prefs.isEnabled('coworking'), isTrue);
  });

  test('preferences survive encode/decode for local persistence', () {
    final prefs = CustomerCategoryPreferences.fromEnabled(
      ['hotels', 'pg'],
      const {'hotels': true, 'pg': false},
    );
    final restored = CustomerCategoryPreferences.fromEnabled(
      ['hotels', 'pg'],
      CustomerCategoryPreferences.decode(prefs.encode()),
    );
    expect(restored.visibleIds, ['hotels']);
  });
}
