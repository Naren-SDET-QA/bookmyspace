import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin provider screen exposes safe configuration controls', () {
    final source = File('lib/features/admin/presentation/screens/admin_observability_providers_screen.dart').readAsStringSync();
    for (final label in ['Model', 'Priority', 'Retry', 'Input limit', 'Output limit', 'Rate limit', 'Credential']) {
      expect(source, contains(label));
    }
    expect(source, contains('configuration'));
    expect(source, contains('Configured'));
    expect(source, isNot(contains('secret_reference')));
  });
}
