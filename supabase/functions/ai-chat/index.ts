import { createClient } from 'npm:@supabase/supabase-js@2';
import { LocalAiProviderAdapter } from '../_shared/ai_provider_adapter.ts';
import { emitAiEvent } from '../_shared/ai_observability.ts';

const url = Deno.env.get('SUPABASE_URL')!;
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? serviceKey;
const admin = createClient(url, serviceKey);
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function localResponse(input: string) {
  const value = input.toLowerCase();
  const category = value.includes('sports court') || value.includes('court')
    ? 'sports_court'
    : value.includes('function hall') || value.includes('marriage hall')
      ? 'function_hall'
      : undefined;
  return {
    provider: 'local',
    model: 'local-deterministic',
    intent: { intent: 'SEARCH', ...(category ? { category } : {}) },
    handoff: 'ai-clarification-or-action-gate',
  };
}

function selectProvider(rows: Array<Record<string, unknown>>) {
  const enabled = rows
    .filter((row) => row.enabled === true && row.status === 'enabled')
    .filter((row) => row.provider === 'AI' || (row.configuration as Record<string, unknown> | null)?.capability === 'ai')
    .sort((a, b) => Number(b.priority ?? (b.configuration as Record<string, unknown> | null)?.priority ?? 0) - Number(a.priority ?? (a.configuration as Record<string, unknown> | null)?.priority ?? 0));
  return { primary: enabled[0], fallback: enabled[1] };
}

async function resolveTrustedContext(body: Record<string, unknown>) {
  const resourceId = typeof body.resource_id === 'string' ? body.resource_id : '';
  if (!resourceId) return { organizationId: null, categoryId: null, configuration: {} as Record<string, unknown> };
  const { data: venue } = await admin.from('venues').select('org_id,category_id').eq('id', resourceId).maybeSingle();
  if (!venue) return { organizationId: null, categoryId: null, configuration: {} as Record<string, unknown> };
  const { data: tenant } = await admin.from('organization_configurations').select('features,voice,categories').eq('organization_id', venue.org_id).maybeSingle();
  const { data: category } = await admin.from('organization_category_configurations').select('configuration').eq('organization_id', venue.org_id).eq('category_id', venue.category_id).maybeSingle();
  const features = (tenant?.features ?? {}) as Record<string, unknown>;
  const categoryConfiguration = (category?.configuration ?? {}) as Record<string, unknown>;
  const categoryAi = (categoryConfiguration.ai ?? {}) as Record<string, unknown>;
  const tenantAi = (features.ai ?? {}) as Record<string, unknown>;
  return {
    organizationId: venue.org_id as string,
    categoryId: venue.category_id as string,
    configuration: { ...tenantAi, ...categoryAi, enabled: categoryAi.enabled ?? tenantAi.enabled },
  };
}

async function handle(req: Request) {
  const authorization = req.headers.get('Authorization');
  if (!authorization?.startsWith('Bearer ')) return json({ error: 'unauthorized' }, 401);

  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
  });
  const { data: { user }, error } = await userClient.auth.getUser();
  if (error || !user) return json({ error: 'unauthorized' }, 401);

  const body = await req.json().catch(() => null);
  const input = typeof body?.input === 'string' ? body.input.trim() : '';
  if (!input) return json({ error: 'invalid_request' }, 400);
  if (input.length > 8000) return json({ error: 'AI_RATE_LIMITED', reason: 'input_too_large' }, 413);

  const trusted = await resolveTrustedContext((body ?? {}) as Record<string, unknown>);
  if (trusted.configuration.enabled === false) return json({ error: 'FEATURE_DISABLED' }, 409);

  const { data: configs } = await admin
    .from('integrations')
    .select('slug,provider,enabled,status,configuration,organization_id,display_order')
    .eq('enabled', true)
    .eq('status', 'enabled');
  const scopedConfigs = (configs ?? []).filter((row) => row.organization_id == null || row.organization_id === trusted.organizationId);
  const selected = selectProvider(scopedConfigs as Array<Record<string, unknown>>);
  const aiConfig = selected.primary;
  const selectedProvider = String(aiConfig?.provider ?? 'local');
  await emitAiEvent(admin, {
    event: 'ai_provider_selected',
    provider: selectedProvider,
    organizationId: trusted.organizationId,
    categoryId: trusted.categoryId,
    status: 'selected',
    fallbackUsed: false,
  });
  if (aiConfig == null && body?.provider !== undefined) {
    return json({ error: 'INVALID_CONFIGURATION' }, 409);
  }

  // The limiter is a fail-safe additive capability: once its local migration
  // is applied it is authoritative and atomic; an older database remains
  // usable until the migration is reviewed and applied.
  const { data: limitRows, error: limitError } = await userClient.rpc('consume_ai_rate_limit', {
    p_provider: String(aiConfig?.provider ?? 'local'),
    p_limit: Number((aiConfig?.configuration as Record<string, unknown> | null)?.rate_limit ?? 20),
    p_window_seconds: 60,
  });
  if (!limitError && Array.isArray(limitRows) && limitRows[0]?.allowed === false) {
    await emitAiEvent(admin, {
      event: 'ai_rate_limited',
      provider: selectedProvider,
      organizationId: trusted.organizationId,
      categoryId: trusted.categoryId,
      status: 'rate_limited',
      errorCode: 'AI_RATE_LIMITED',
    });
    return json({ error: 'AI_RATE_LIMITED' }, 429);
  }

  const providerName = String(aiConfig?.provider ?? 'local');
  const { data: circuitRows, error: circuitError } = await userClient.rpc('ai_circuit_admit', {
    p_component: 'ai-chat',
    p_provider: providerName,
    p_failure_threshold: 3,
    p_cooldown_seconds: 60,
  });
  if (!circuitError && Array.isArray(circuitRows) && circuitRows[0]?.allowed === false) {
    await emitAiEvent(admin, {
      event: 'ai_circuit_open',
      provider: providerName,
      organizationId: trusted.organizationId,
      categoryId: trusted.categoryId,
      status: 'circuit_open',
      errorCode: 'AI_PROVIDER_UNAVAILABLE',
    });
    return json({ error: 'AI_PROVIDER_UNAVAILABLE', circuit_state: circuitRows[0]?.state }, 503);
  }

  // The local provider is deterministic and credential-free. External providers
  // are intentionally not called until their server-side adapter is configured.
  const adapter = new LocalAiProviderAdapter(providerName);
  const response = await adapter.generate({ input, model: String((aiConfig?.configuration as Record<string, unknown> | null)?.model ?? 'local-deterministic') });
  await userClient.rpc('ai_circuit_record_result', {
    p_component: 'ai-chat',
    p_provider: providerName,
    p_succeeded: true,
    p_error: null,
  });
  await emitAiEvent(admin, {
    event: 'ai_provider_success',
    provider: response.provider,
    model: response.model,
    organizationId: trusted.organizationId,
    categoryId: trusted.categoryId,
    status: 'success',
    fallbackUsed: selected.fallback != null,
  });
  return json({
    data: { provider: response.provider, model: response.model, intent: JSON.parse(response.text), handoff: 'ai-clarification-or-action-gate' },
    provider_configured: aiConfig != null,
    action_gate_required: true,
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
  try {
    return await handle(req);
  } catch (_) {
    return json({ error: 'AI_PROVIDER_UNAVAILABLE' }, 503);
  }
});
