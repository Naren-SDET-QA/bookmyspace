import { buildHeaders, buildRequestUrl, redactSensitive } from '../integration-executor/executor_policy.ts';

export type ProviderRequest = { input: string; model?: string; timeoutMs?: number };
export type ProviderResult = { provider: string; model: string; text: string; usedFallback: boolean };

export interface ServerAiProviderAdapter {
  generate(request: ProviderRequest): Promise<ProviderResult>;
  healthCheck(): Promise<boolean>;
}

export class LocalAiProviderAdapter implements ServerAiProviderAdapter {
  constructor(private readonly provider = 'local') {}
  async generate(request: ProviderRequest): Promise<ProviderResult> {
    const value = request.input.toLowerCase();
    const category = value.includes('sports court') || value.includes('court')
      ? 'sports_court'
      : value.includes('function hall') || value.includes('marriage hall')
        ? 'function_hall'
        : undefined;
    return { provider: this.provider, model: request.model ?? 'local-deterministic', usedFallback: false, text: JSON.stringify({ intent: 'SEARCH', ...(category ? { category } : {}) }) };
  }
  async healthCheck(): Promise<boolean> { return true; }
}

export function safeProviderError(error: unknown): string {
  const redacted = redactSensitive({ error: error instanceof Error ? error.message : String(error) });
  return typeof redacted === 'object' ? 'provider_unavailable' : String(redacted);
}

export function configuredProviderUrl(baseUrl: string, endpoint: string, input: Record<string, unknown>): string {
  return buildRequestUrl(baseUrl, endpoint, input);
}

export function configuredProviderHeaders(
  template: Record<string, unknown>,
  authenticationType: string,
  secret?: string,
): Headers {
  return buildHeaders(template, authenticationType, secret);
}
