import 'package:bookmyspace/core/modular/mutation_guard.dart';
import 'package:bookmyspace/core/modular/self_healing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('self-healing never duplicates a booking or payment operation', () async {
    final guard = MutationGuard();
    expect(guard.tryBegin('booking:create:hold-1'), isTrue);
    expect(guard.tryBegin('booking:create:hold-1'), isFalse);
    expect(guard.tryBegin('payment:order:b1'), isTrue);
    expect(guard.tryBegin('payment:order:b1'), isFalse);

    var bookingCalls = 0;
    final healing = SelfHealing(mutationGuard: guard);
    await expectLater(
      healing.runMutation(
        key: 'booking:create:hold-1',
        action: () async {
          bookingCalls++;
          return 'created';
        },
      ),
      throwsA(isA<StateError>()),
    );
    expect(bookingCalls, 0);

    var searches = 0;
    final value = await healing.runIdempotentRead(
      action: () async {
        searches++;
        if (searches < 2) throw Exception('timeout');
        return 'ok';
      },
    );
    expect(value, 'ok');
    expect(searches, 2);
  });
}
