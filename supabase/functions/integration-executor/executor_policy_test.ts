import {
  applyMapping,
  buildHeaders,
  buildRequestUrl,
  isAllowedDestination,
  redactSensitive,
  retryDelayMs,
  shouldRetry,
} from './executor_policy.ts';

Deno.test('supports path and query parameters without allowing URL escape', () => {
  const url = buildRequestUrl('https://api.example.com/v1', '/users/{user_id}', { user_id: 'u/1', page: 2 });
  if (url !== 'https://api.example.com/v1/users/u%2F1?page=2') throw new Error(`unexpected URL ${url}`);
});

Deno.test('maps request and response fields using configured paths', () => {
  const request = applyMapping({ phone: '123', message: 'hello' }, [{ source_path: 'phone', target_path: 'recipient' }]);
  const response = applyMapping({ success: true, data: { id: 'msg-1' } }, [{ source_path: 'data.id', target_path: 'external_id' }]);
  if (request.recipient !== '123' || response.external_id !== 'msg-1') throw new Error('mapping failed');
});

Deno.test('builds supported authentication headers without exposing secrets', () => {
  const bearer = buildHeaders({}, 'BEARER_TOKEN', 'secret');
  const apiKey = buildHeaders({ 'X-Provider': 'demo' }, 'API_KEY', 'secret');
  if (bearer.get('authorization') !== 'Bearer secret' || apiKey.get('x-api-key') !== 'secret') throw new Error('auth header failed');
});

Deno.test('rejects private and client-supplied destinations', () => {
  if (isAllowedDestination('http://127.0.0.1:54321')) throw new Error('private host allowed');
  if (isAllowedDestination('http://169.254.169.254/latest')) throw new Error('metadata host allowed');
  if (!isAllowedDestination('https://api.example.com')) throw new Error('public host rejected');
});

Deno.test('builds a configured URL without accepting an arbitrary absolute endpoint', () => {
  const url = buildRequestUrl('https://api.example.com/v1', '/bookings', { page: '1' });
  if (url !== 'https://api.example.com/v1/bookings?page=1') throw new Error(`unexpected URL ${url}`);
  let rejected = false;
  try { buildRequestUrl('https://api.example.com/v1', 'https://evil.example.com', {}); } catch (_) { rejected = true; }
  if (!rejected) throw new Error('absolute endpoint escaped configured base URL');
});

Deno.test('redacts credential-bearing keys and authorization headers', () => {
  const result = redactSensitive({ token: 'secret', authorization: 'Bearer secret', nested: { password: 'pw' } });
  if (JSON.stringify(result).includes('secret') || JSON.stringify(result).includes('pw')) throw new Error('secret leaked');
});

Deno.test('retries only transient failures with bounded backoff', () => {
  if (!shouldRetry(503, 1, 3) || shouldRetry(400, 1, 3) || shouldRetry(503, 3, 3)) throw new Error('retry policy incorrect');
  if (retryDelayMs(1, 100) !== 100 || retryDelayMs(9, 100) !== 2000) throw new Error('backoff is not bounded');
});
