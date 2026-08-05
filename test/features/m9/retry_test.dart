import 'package:bookmyspace/core/network/retry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('withRetry', () {
    test('returns result on first success', () async {
      final result = await withRetry(() async => 42);
      expect(result, 42);
    });

    test('retries on failure and eventually succeeds', () async {
      var attempts = 0;
      final result = await withRetry(
        () async {
          attempts++;
          if (attempts < 3) throw Exception('Transient error');
          return 'success';
        },
        config: const RetryConfig(
          maxRetries: 3,
          initialDelay: Duration(milliseconds: 1),
        ),
      );
      expect(result, 'success');
      expect(attempts, 3);
    });

    test('throws after exhausting retries', () async {
      expect(
        () => withRetry(
          () async {
            throw Exception('Persistent error');
          },
          config: const RetryConfig(
            maxRetries: 2,
            initialDelay: Duration(milliseconds: 1),
          ),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('respects retryWhen predicate', () async {
      var attempts = 0;
      expect(
        () => withRetry(
          () async {
            attempts++;
            throw const FormatException('Non-retryable');
          },
          config: const RetryConfig(
            maxRetries: 3,
            initialDelay: Duration(milliseconds: 1),
          ),
          retryWhen: (e) => e is! FormatException,
        ),
        throwsA(isA<FormatException>()),
      );
      expect(attempts, 1);
    });
  });

  group('RateLimiter', () {
    test('allows requests within limit', () {
      final limiter = RateLimiter(maxRequests: 5, window: const Duration(seconds: 1));
      for (var i = 0; i < 5; i++) {
        limiter.checkAllowed();
      }
    });

    test('throws RateLimitException when limit exceeded', () {
      final limiter = RateLimiter(maxRequests: 2, window: const Duration(seconds: 60));
      limiter.checkAllowed();
      limiter.checkAllowed();
      expect(() => limiter.checkAllowed(), throwsA(isA<RateLimitException>()));
    });
  });
}
