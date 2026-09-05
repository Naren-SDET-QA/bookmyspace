import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/admin/domain/admin_settings.dart';

void main() {
  test('safe defaults are used for missing and invalid values', () {
    expect(AdminSettings.text(null, 'fallback'), 'fallback');
    expect(AdminSettings.flag('true'), isFalse);
    expect(AdminSettings.validHex('#112233'), isTrue);
    expect(AdminSettings.validHex('#11223344'), isTrue);
    expect(AdminSettings.validHex('112233'), isFalse);
    expect(AdminSettings.color('invalid', Colors.blue), Colors.blue);
    expect(
      AdminSettings.color('#112233', Colors.blue),
      const Color(0xFF112233),
    );
  });

  test('default settings contain safe home and theme values', () {
    expect(AdminSettings.defaults.home['hero_title'], isNotEmpty);
    expect(AdminSettings.defaults.theme['primary_color'], '#3F51B5');
  });
}
