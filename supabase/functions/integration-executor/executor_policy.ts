const SENSITIVE_KEY = /(authorization|token|secret|password|api[_-]?key|credential|cookie)/i;

export function isAllowedDestination(raw: string): boolean {
  try {
    const url = new URL(raw);
    if (url.protocol !== 'https:' || url.username || url.password) return false;
    const host = url.hostname.toLowerCase();
    if (host === 'localhost' || host.endsWith('.localhost') || host === 'metadata.google.internal') return false;
    if (/^(127\.|10\.|192\.168\.|169\.254\.)/.test(host)) return false;
    if (/^172\.(1[6-9]|2\d|3[01])\./.test(host)) return false;
    if (host === '::1' || host.startsWith('fc') || host.startsWith('fd') || host.startsWith('fe80:')) return false;
    return true;
  } catch (_) {
    return false;
  }
}

export function buildRequestUrl(baseUrl: string, endpoint: string, query: Record<string, unknown>): string {
  if (!isAllowedDestination(baseUrl)) throw new Error('destination_not_allowed');
  if (/^[a-z][a-z\d+.-]*:/i.test(endpoint) || endpoint.startsWith('//')) {
    throw new Error('absolute_endpoint_not_allowed');
  }
  let resolvedEndpoint = endpoint;
  for (const match of endpoint.matchAll(/\{([^}]+)\}/g)) {
    const value = query[match[1]];
    if (value == null) throw new Error('missing_path_parameter');
    resolvedEndpoint = resolvedEndpoint.replace(match[0], encodeURIComponent(String(value)));
  }
  const url = new URL(resolvedEndpoint.replace(/^\//, ''), `${baseUrl.replace(/\/$/, '')}/`);
  for (const [key, value] of Object.entries(query)) {
    if (value != null && !endpoint.includes(`{${key}}`)) url.searchParams.set(key, String(value));
  }
  return url.toString();
}

function readPath(value: unknown, path: string): unknown {
  return path.split('.').filter(Boolean).reduce<unknown>((current, key) => {
    if (!current || typeof current !== 'object') return undefined;
    return (current as Record<string, unknown>)[key];
  }, value);
}

export function applyMapping(input: Record<string, unknown>, mappings: Array<{ source_path: string; target_path: string }>): Record<string, unknown> {
  const output: Record<string, unknown> = {};
  for (const mapping of mappings) {
    const value = readPath(input, mapping.source_path);
    if (value === undefined) continue;
    const keys = mapping.target_path.split('.');
    let cursor = output;
    keys.forEach((key, index) => {
      if (index === keys.length - 1) cursor[key] = value;
      else cursor = (cursor[key] ??= {}) as Record<string, unknown>;
    });
  }
  return output;
}

export function buildHeaders(headers: Record<string, unknown>, authType: string, secret?: string, customHeader = 'X-API-Key'): Headers {
  const result = new Headers({ Accept: 'application/json', 'Content-Type': 'application/json' });
  for (const [key, value] of Object.entries(headers)) result.set(key, String(value));
  if (!secret) return result;
  if (authType === 'BEARER_TOKEN') result.set('Authorization', `Bearer ${secret}`);
  else if (authType === 'API_KEY') result.set('X-API-Key', secret);
  else if (authType === 'BASIC_AUTH') result.set('Authorization', `Basic ${btoa(secret)}`);
  else if (authType === 'CUSTOM_HEADER') result.set(customHeader, secret);
  return result;
}

export function shouldRetry(status: number, attempt: number, maxAttempts: number): boolean {
  return attempt < Math.min(Math.max(maxAttempts, 1), 4) && (status === 408 || status === 425 || status === 429 || status >= 500);
}

export function retryDelayMs(attempt: number, baseMs = 250): number {
  return Math.min(baseMs * (2 ** Math.max(attempt - 1, 0)), 2000);
}

export function redactSensitive(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(redactSensitive);
  if (value && typeof value === 'object') {
    const output: Record<string, unknown> = {};
    for (const [key, child] of Object.entries(value)) {
      output[key] = SENSITIVE_KEY.test(key) ? '[REDACTED]' : redactSensitive(child);
    }
    return output;
  }
  return value;
}
