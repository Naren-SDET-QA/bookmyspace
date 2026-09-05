import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/ai/domain/action_gate_policy.dart';

void main() {
  test('anonymous mutation is rejected with structured error', () {
    final result = ActionGatePolicy.check(
      action: UniversalAction.confirmBooking,
      authenticated: false,
      confirmed: true,
    );
    expect(result.error, ActionGateError.unauthenticated);
  });

  test('financial action requires explicit confirmation', () {
    final result = ActionGatePolicy.check(
      action: UniversalAction.createHold,
      authenticated: true,
      confirmed: false,
    );
    expect(result.error, ActionGateError.confirmationRequired);
  });

  test('AI supplied protected fields are rejected', () {
    for (final field in [
      'user_id',
      'tenant_id',
      'organization_id',
      'resource_id',
      'venue_id',
      'price',
      'tax',
      'total',
      'permissions',
    ]) {
      final result = ActionGatePolicy.check(
        action: UniversalAction.search,
        authenticated: true,
        confirmed: true,
        suppliedFields: {field: 'attacker'},
      );
      expect(result.error, ActionGateError.unauthorizedInput, reason: field);
    }
  });

  test('informational action is allowed for an authenticated user', () {
    final result = ActionGatePolicy.check(
      action: UniversalAction.bookingStatus,
      authenticated: true,
    );
    expect(result.allowed, isTrue);
  });
}
