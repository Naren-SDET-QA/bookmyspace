import 'package:bookmyspace/core/network/retry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'withRetry recovers transient failures without duplicating success',
    () async {
      var attempts = 0;
      final result = await withRetry<int>(() async {
        attempts++;
        if (attempts < 3) throw StateError('temporary');
        return 42;
      }, config: const RetryConfig(maxRetries: 3, initialDelay: Duration.zero));
      expect(result, 42);
      expect(attempts, 3);
    },
  );

  test('withRetry does not retry non-retryable failures', () async {
    var attempts = 0;
    await expectLater(
      withRetry<void>(
        () async {
          attempts++;
          throw StateError('invalid input');
        },
        config: const RetryConfig(maxRetries: 3, initialDelay: Duration.zero),
        retryWhen: (_) => false,
      ),
      throwsStateError,
    );
    expect(attempts, 1);
  });
}
