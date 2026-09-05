enum MediaFailureKind {
  transient,
  invalidFile,
  capabilityDisabled,
  unauthorized,
  invalidVenue,
  invalidMediaType,
  unknown,
}

class MediaFailure implements Exception {
  const MediaFailure(this.kind, [this.message = 'Media operation failed.']);

  final MediaFailureKind kind;
  final String message;

  @override
  String toString() => message;
}

class MediaRetryPolicy {
  const MediaRetryPolicy({this.maxAttempts = 3});

  final int maxAttempts;

  Future<T> run<T>({
    required Future<T> Function(int attempt) operation,
    Future<void> Function(Duration delay)? wait,
  }) async {
    final attempts = maxAttempts.clamp(1, 3);
    var attempt = 1;
    while (true) {
      try {
        return await operation(attempt);
      } catch (error) {
        if (!_isTransient(error) || attempt >= attempts) rethrow;
        final delay = Duration(milliseconds: attempt == 1 ? 150 : 400);
        if (wait != null) {
          await wait(delay);
        } else {
          await Future<void>.delayed(delay);
        }
        attempt++;
      }
    }
  }

  bool _isTransient(Object error) =>
      error is MediaFailure && error.kind == MediaFailureKind.transient;
}
