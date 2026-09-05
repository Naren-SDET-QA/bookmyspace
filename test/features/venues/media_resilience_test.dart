import 'package:flutter_test/flutter_test.dart';

import '../../../lib/features/venues/domain/media_resilience.dart';

void main() {
  test('retries transient failures at most three times', () async {
    var attempts = 0;
    final result = await const MediaRetryPolicy().run<String>(
      operation: (_) async {
        attempts++;
        if (attempts < 3) throw const MediaFailure(MediaFailureKind.transient);
        return 'ready';
      },
      wait: (_) async {},
    );

    expect(result, 'ready');
    expect(attempts, 3);
  });

  test('permanent failures are not retried', () async {
    var attempts = 0;
    await expectLater(
      const MediaRetryPolicy().run<void>(
        operation: (_) async {
          attempts++;
          throw const MediaFailure(MediaFailureKind.invalidFile);
        },
        wait: (_) async {},
      ),
      throwsA(isA<MediaFailure>()),
    );
    expect(attempts, 1);
  });

  test('three transient failures end in failure', () async {
    var attempts = 0;
    await expectLater(
      const MediaRetryPolicy().run<void>(
        operation: (_) async {
          attempts++;
          throw const MediaFailure(MediaFailureKind.transient);
        },
        wait: (_) async {},
      ),
      throwsA(isA<MediaFailure>()),
    );
    expect(attempts, 3);
  });
}
