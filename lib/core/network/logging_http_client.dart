import 'dart:async';

import 'package:http/http.dart' as http;

import '../debug/debug_log.dart';

/// HTTP client that records every request/response to the in-memory debug
/// log. It is only installed when Test Mode network logging is enabled and
/// transparently delegates to the real transport — no mock or proxy.
class LoggingHttpClient extends http.BaseClient {
  LoggingHttpClient(this._inner);

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final sw = Stopwatch()..start();
    DebugLog.debug(
      'HTTP',
      '${request.method} ${request.url}',
      detail: request.headers.entries
          .map((e) => '${e.key}=${_redact(e.key, e.value)}')
          .join(', '),
    );
    try {
      final response = await _inner.send(request);
      sw.stop();
      final bytes = await response.stream.toBytes();
      DebugLog.debug(
        'HTTP',
        '${request.method} ${request.url} -> ${response.statusCode} (${sw.elapsedMilliseconds}ms)',
        detail: _truncate(String.fromCharCodes(bytes)),
      );
      return http.StreamedResponse(
        Stream.value(bytes),
        response.statusCode,
        contentLength: bytes.length,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } catch (e) {
      sw.stop();
      DebugLog.error(
        'HTTP',
        '${request.method} ${request.url} FAILED after ${sw.elapsedMilliseconds}ms',
        detail: e.toString(),
      );
      rethrow;
    }
  }

  String _truncate(String s) =>
      s.length <= 500 ? s : '${s.substring(0, 500)}…(${s.length} chars)';

  String _redact(String key, String value) {
    const sensitive = {
      'authorization',
      'apikey',
      'api_key',
      'x-supabase-key',
      'cookie',
      'set-cookie',
    };
    if (sensitive.contains(key.toLowerCase())) return '***';
    return value;
  }

  @override
  void close() => _inner.close();
}
