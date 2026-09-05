import { redactSensitive } from '../integration-executor/executor_policy.ts';

export const AI_EVENTS = [
  'ai_provider_selected',
  'ai_provider_success',
  'ai_provider_failure',
  'ai_provider_fallback',
  'ai_provider_test',
  'ai_rate_limited',
  'ai_circuit_open',
  'ai_circuit_recovery',
] as const;

type AiEvent = (typeof AI_EVENTS)[number];

type AiEventInput = {
  event: AiEvent;
  provider: string;
  model?: string;
  intent?: string;
  latencyMs?: number;
  status: string;
  errorCode?: string;
  fallbackUsed?: boolean;
  organizationId?: string | null;
  categoryId?: string | null;
};

export async function emitAiEvent(client: { from: (table: string) => any }, input: AiEventInput): Promise<void> {
  try {
    const details = redactSensitive({
      event: input.event,
      provider: input.provider.slice(0, 120),
      model: input.model?.slice(0, 120),
      intent: input.intent?.slice(0, 120),
      latency_ms: input.latencyMs,
      status: input.status.slice(0, 40),
      error_code: input.errorCode?.slice(0, 80),
      fallback_used: input.fallbackUsed === true,
      organization_id: input.organizationId ?? null,
      category_id: input.categoryId ?? null,
    });
    await client.from('error_events').insert({
      feature: 'ai',
      category: input.categoryId ?? null,
      severity: input.status === 'success' ? 'info' : 'error',
      status: input.status === 'success' ? 'resolved' : 'open',
      last_error: input.errorCode?.slice(0, 80) ?? null,
      details,
    });
  } catch (_) {
    // Observability is deliberately non-authoritative: never fail AI requests.
  }
}
