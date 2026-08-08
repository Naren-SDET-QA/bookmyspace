import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Severity levels for [DebugLogEntry].
enum DebugLogLevel {
  verbose,
  debug,
  info,
  warning,
  error,
}

/// A single in-memory log entry captured while Test Mode is enabled.
class DebugLogEntry {
  const DebugLogEntry({
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
    this.detail,
  });

  final DateTime timestamp;
  final DebugLogLevel level;
  final String source;
  final String message;
  final String? detail;

  String get timestampLabel {
    final t = timestamp;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}

/// Process-wide ring buffer for session logs.
///
/// A singleton sink is used so that any layer (HTTP client, repositories,
/// screens) can append entries without needing a Riverpod container. The
/// debug menu subscribes to [DebugLog.stream] / [debugLogProvider].
class DebugLog {
  DebugLog._();

  static const int _maxEntries = 500;
  static final List<DebugLogEntry> _entries = [];
  static final StreamController<List<DebugLogEntry>> _controller =
      StreamController.broadcast();

  static List<DebugLogEntry> get entries => List.unmodifiable(_entries);

  static Stream<List<DebugLogEntry>> get stream => _controller.stream;

  static void write(
    DebugLogLevel level,
    String source,
    String message, {
    String? detail,
  }) {
    final entry = DebugLogEntry(
      timestamp: DateTime.now(),
      level: level,
      source: source,
      message: message,
      detail: detail,
    );
    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }
    if (!_controller.isClosed) {
      _controller.add(List.unmodifiable(_entries));
    }
  }

  static void verbose(
    String source,
    String message, {
    String? detail,
  }) =>
      write(DebugLogLevel.verbose, source, message, detail: detail);
  static void debug(
    String source,
    String message, {
    String? detail,
  }) =>
      write(DebugLogLevel.debug, source, message, detail: detail);
  static void info(
    String source,
    String message, {
    String? detail,
  }) =>
      write(DebugLogLevel.info, source, message, detail: detail);
  static void warning(
    String source,
    String message, {
    String? detail,
  }) =>
      write(DebugLogLevel.warning, source, message, detail: detail);
  static void error(
    String source,
    String message, {
    String? detail,
  }) =>
      write(DebugLogLevel.error, source, message, detail: detail);

  static void clear() {
    _entries.clear();
    if (!_controller.isClosed) _controller.add(const []);
  }
}

/// Stream of debug log entries, consumed by the debug menu.
final debugLogProvider = StreamProvider<List<DebugLogEntry>>(
  (ref) => DebugLog.stream,
);

/// Resets the in-memory log (used by the "Test Data Reset" debug action).
final clearDebugLogProvider = Provider<void>((ref) {
  return DebugLog.clear();
});
