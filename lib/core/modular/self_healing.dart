import '../network/retry.dart';
import 'mutation_guard.dart';

/// Bounded recovery for reads and plugin init. Never retries mutations.
class SelfHealing {
  SelfHealing({MutationGuard? mutationGuard})
    : mutationGuard = mutationGuard ?? MutationGuard();

  final MutationGuard mutationGuard;

  Future<T> runIdempotentRead<T>({
    required Future<T> Function() action,
    RetryConfig config = const RetryConfig(
      maxRetries: 3,
      initialDelay: Duration(milliseconds: 1),
      maxDelay: Duration(milliseconds: 20),
    ),
  }) {
    return withRetry(action, config: config);
  }

  Future<T> runMutation<T>({
    required String key,
    required Future<T> Function() action,
  }) async {
    if (!mutationGuard.tryBegin(key)) {
      throw StateError('Refusing duplicate mutation for $key');
    }
    return action();
  }
}
