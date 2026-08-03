import 'dart:async';

/// Retry configuration for API calls.
class RetryConfig {
  const RetryConfig({
    this.maxRetries = 3,
    this.initialDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 5),
    this.backoffMultiplier = 2.0,
  });

  final int maxRetries;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;

  /// Default config with exponential backoff.
  static const defaultConfig = RetryConfig();
}

/// Executes an async operation with exponential-backoff retry logic.
///
/// Returns the result on success, or rethrows the last exception
/// after all retries are exhausted.
Future<T> withRetry<T>(
  Future<T> Function() operation, {
  RetryConfig config = RetryConfig.defaultConfig,
  bool Function(Object error)? retryWhen,
}) async {
  var attempt = 0;
  var delay = config.initialDelay;

  while (true) {
    try {
      return await operation();
    } catch (e) {
      attempt++;
      if (attempt >= config.maxRetries) rethrow;
      if (retryWhen != null && !retryWhen(e)) rethrow;

      await Future<void>.delayed(delay);
      delay = Duration(
        milliseconds: (delay.inMilliseconds * config.backoffMultiplier).round(),
      );
      if (delay > config.maxDelay) delay = config.maxDelay;
    }
  }
}

/// Rate-limit aware wrapper. Tracks request timestamps and throws
/// [RateLimitException] if too many requests are made in a window.
class RateLimiter {
  RateLimiter({this.maxRequests = 30, this.window = const Duration(minutes: 1)});

  final int maxRequests;
  final Duration window;
  final List<DateTime> _timestamps = [];

  /// Check if a new request is allowed. Throws [RateLimitException] if not.
  void checkAllowed() {
    final now = DateTime.now();
    _timestamps.removeWhere((t) => now.difference(t) > window);
    if (_timestamps.length >= maxRequests) {
      final oldest = _timestamps.first;
      final waitTime = window - now.difference(oldest);
      throw RateLimitException(
        'Too many requests. Please wait ${waitTime.inSeconds} seconds.',
        retryAfter: waitTime,
      );
    }
    _timestamps.add(now);
  }
}

/// Thrown when rate limit is exceeded.
class RateLimitException implements Exception {
  const RateLimitException(this.message, {required this.retryAfter});

  final String message;
  final Duration retryAfter;

  @override
  String toString() => 'RateLimitException: $message (retry after ${retryAfter.inSeconds}s)';
}
