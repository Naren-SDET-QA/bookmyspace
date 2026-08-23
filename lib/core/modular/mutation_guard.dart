/// Prevents self-healing from repeating booking/payment mutations.
class MutationGuard {
  final Set<String> _started = <String>{};

  /// Returns false when [key] has already begun.
  bool tryBegin(String key) => _started.add(key);

  bool hasStarted(String key) => _started.contains(key);
}
